# Outputs directory

Each csv file in this folder has been generating by scripts in the repository. 

The files are grouped by variable and contain information on:
- CMIP6 model, experiment, and ensemble
- Variable name and units
- Time series information and value per time segment, i.e., an annual file will give the value of a variable in each year (which may have been averaged annually from monthly data)
- Other relevant information; for example:
  - `tas` output files also have `Tgav` numbers where applicable and a column detailing if it is global temperature or temperature averaged over land. 
  - The heat flux output file has data on each component's value as well as a final number for the heat flux equation.
  