This plugin reports Reek reports in Jenkins.

Run the Reek tool by:
reek -y <folders or files to be checked> | tee <report>.yaml

example:
reel -y src | tee reek_report.yaml

Use this plugin by specifying the relative path to the report in the configuration.
