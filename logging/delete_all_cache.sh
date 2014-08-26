#!/bin/bash


read -p "Are you sure you want to continue? <y/N> " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]
then
  echo "okay lets delete that data"
  # http://stackoverflow.com/questions/1537673/how-do-i-forward-parameters-to-other-command-in-bash-script
else
  exit 0
fi

service logstash stop
service elasticsearch stop

rm /var/lib/logstash/.sincedb*
rm -r /var/lib/elasticsearch/*



service elasticsearch start
service logstash start
