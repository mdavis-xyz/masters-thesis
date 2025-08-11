import json

from jinja2 import Environment, FileSystemLoader


with open('results/regression-results.json', 'r') as f:
    results = json.load(f)


env = Environment(loader=FileSystemLoader('.'))
template = env.get_template('table.typ.jinja')

coefficients_to_include = {
    "GENERATION_EXCL_ROOFTOP_GW": {
        "label": "Generation Excl. Rooftop",
        "param": "$beta$",
    },
    "ROOFTOP_POWER_GW": {
        "label": "Rooftop PV"
    }, 
    "CONNECTED_INERTIA_GW": {
        "label": "Spinning Inertial \\ Capacity",
        "param": "$gamma_1$",
    },
    #"BIGGEST_CONTINGENCY_GW": "Biggest Transmission or Gen. (GW)",
}

durations = {
    "6SEC": "6 Sec",
    "60SEC": "60 Sec",
    "5MIN": "5 MIN"
}

star_levels = [0.1, 0.05, 0.01]


for model in results:
    # add stars
    for c in model['coefficients']:
        c['stars'] = sum(p >= c['p_value'] for p in star_levels)

    model['coefficients'] = {
        c['term']: c for c in model['coefficients']
    }

    #assert 'TOTAL_CONSUMPTION_GW' in model['coefficients'], "Model is missing TOTAL_CONSUMPTION_GW"

    model['time_fe'] = False
    for c in model['coefficients']:
        for d in ["HOUR", "DAY_OF_WEEK", "MONTH", "IS_WEEKEND", "IS_WEEKDAY", "IS_HOLIDAY"]:
            model['time_fe'] |= c.startswith(d)

    model["controls"] = any(coef.startswith("BIGGEST_") for coef in model["coefficients"])

output_paths = []

for fcas_duration in durations.keys():

    models = [m for m in results if m['metadata']['fcas_duration'][0] == fcas_duration]
    rendered = template.render(models=models, coefficients_to_include=coefficients_to_include, star_levels=star_levels)

    output_path = f'results/regression-table-{fcas_duration}.typ'
    output_paths.append(output_path)

    with open(output_path, 'w') as f:
        f.write(rendered)

with open('results/regression-table-combined.typ', 'w') as f_out:
    for path in output_paths:
        with open(path, 'r') as f_in:
            f_out.write(f_in.read())
            f_out.write("\n")