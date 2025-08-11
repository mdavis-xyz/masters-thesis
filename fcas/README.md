# Raise FCAS regressions

This folder contains scripts for the ARIMA regressions about raise reserves.

`temperature-data` contains some raw data, which was not actually used in the end.

`01-data-plots.ipynb` downloads the data, and generates some scatter plots.
`
`02-regressions.R` uses that data to run the actual ARIMA regressions.

`03-build-table.py` formats the regression results from R into a typst table to insert into my thesis PDF, using template `table.typ.jinja`.
