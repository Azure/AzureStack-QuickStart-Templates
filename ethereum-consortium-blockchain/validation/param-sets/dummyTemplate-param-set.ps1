# Params for mainTemplate.json
echo "Loading 2 param sets from dummyTemplate-param-set.json"

$paramSet = @{
  "Set1" = @{
    "aparam"                = "param in deploy dud Set1"
  };
  "Set2" = @{
    "aparam"                = "param in deploy dud Set2"
  };
};