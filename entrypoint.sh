#!/bin/bash

CRAC_FILES_DIR=`eval echo ${CRAC_FILES_DIR}`
mkdir -p $CRAC_FILES_DIR

if [ -z "$(ls -A $CRAC_FILES_DIR)" ]; then
  if [ "$FLAG" = "-r" ]; then
    echo 128 > /proc/sys/kernel/ns_last_pid; java -Dspring.context.checkpoint=onRefresh -Dmanagement.endpoint.health.probes.add-additional-paths="true" -Dmanagement.health.probes.enabled="true" -XX:CRaCCheckpointTo=$CRAC_FILES_DIR -jar opt/app/chatbot-0.0.1.jar
  else
    echo 128 > /proc/sys/kernel/ns_last_pid; java -Dmanagement.endpoint.health.probes.add-additional-paths="true" -Dmanagement.health.probes.enabled="true" -XX:CRaCCheckpointTo=$CRAC_FILES_DIR -jar opt/app/chatbot-0.0.1.jar&
    sleep 5
    jcmd opt/app/chatbot-0.0.1.jar JDK.checkpoint
  fi
  sleep infinity
else
  # https://docs.azul.com/core/crac/cpu-features#xxignorecpufeatures
  java -Dmanagement.endpoint.health.probes.add-additional-paths="true" -Dmanagement.health.probes.enabled="true" -XX:CRaCRestoreFrom=$CRAC_FILES_DIR  -XX:+UnlockExperimentalVMOptions -XX:+IgnoreCPUFeatures&
  PID=$!
  trap "kill $PID" SIGINT SIGTERM
  wait $PID
fi