#!/bin/bash
#
# Author: Binh
# Website: https://turndevopseasier.com/
# Puppet Series - Automate configure MySQL Master-Slave Replication
#
#

# Pre-defined variables
master_host="db-01.srv.local";
repl_user="repl_user";
repl_pass="PleaseChangeMe";
db_admin="db_admin";
db_pass="PleaseChangeMe";
REPL_STATE_FILE="/tmp/.replication.done"

echo "$(date) - Configuring Master-Slave replication..."
if ! [ -f $REPL_STATE_FILE ];then
  mysql -e "STOP SLAVE;"
  master_status=$(mysql -h"$master_host" -u"$db_admin" -p"$db_pass" -ANe "SHOW MASTER STATUS;" | awk '{print $1 " " $2}') && \
  master_log_file=$(echo $master_status | cut -d" " -f1) && \
  master_log_pos=$(echo $master_status | cut -d" " -f2)
  mysql -e "RESET SLAVE;"
  mysql -e "CHANGE MASTER TO MASTER_HOST='$master_host', MASTER_PORT=3306, MASTER_USER='$repl_user', MASTER_PASSWORD='$repl_pass', MASTER_LOG_FILE='${master_log_file}', MASTER_LOG_POS='${master_log_pos}';"
  mysql -e "START SLAVE;"
  sleep 5;

  mysql -e "SHOW SLAVE STATUS\G;" | grep "Waiting for master"
  slave_status="$?";
  if [ "$slave_status" -eq "0" ];then
    touch $REPL_STATE_FILE
    echo "$(date) >>> DONE - $(hostname) was configured successfully as a slave for $master_host";
  else
    echo "$(date) >>> ERROR - Failed to configure slave";
    exit 1;
  fi
else
  echo "$(date) >>> INFO - $(hostname) is configured as slave already";
fi
