#!/bin/bash

#var
prbServer=http://127.0.0.1:3000
isAlarm=0

# shellcheck disable=SC2162
read -p "prb系统中Lifecycle的peerId：" peerId
if [ -z "$peerId" ]; then peerId=QmXDjWGGEHmrDUKBX1uaGfeZXu466hs9ALS9KGQg3E42D4c; fi
# shellcheck disable=SC2162
read -p "异常报警邮箱：" alarmMail
if [ -z "$alarmMail" ]; then alarmMail=972858472@qq.com; fi

#重连worker
function restart() {
  echo $(date +'%F %T'),"重连worker",$1
  curl -sH "Content-Type: application/json" -d '{"ids":["'$1'"]}' $prbServer/ptp/proxy/$peerId/RestartWorker
}

#发送邮箱消息
function sendMail() {
  echo $(date +'%F %T'),"sendMail"
  echo "worker error" | mail -s "phala alarm" $alarmMail
}

#是否报警
function isAlarm() {
  isErr=0
  #循环worker的错误次数数组
  for errCount in ${echo $workerArray[*]}; do
    #是否有超过5次的worker
    if [ $errCount -gt 5 ]; then
      let isErr+=1
      remain=$(expr $errCount % 720)
      #是否满足报警条件
      if [ $isAlarm -eq 0 -o $remain -eq 0 ]; then
        isAlarm=1
        sendMail
      fi
      break
    fi
  done

  #无异常worker重置报警标志
  if [ $isErr -eq 0 ]; then
    isAlarm=0
  fi
}

while true; do
  workerStatusList=$(curl -s ${prbServer}/ptp/proxy/${peerId}/GetWorkerStatus | jq '.data.workerStates')
  for key in $(echo "$workerStatusList" | jq 'keys|.[]'); do
    worker=$(echo "$workerStatusList" | jq ".[$key]")
    uuid=$(echo "$worker" | jq -r '.worker.uuid')
    state=$(echo "$worker" | jq -r '.status')
    height=$(echo "$worker" | jq -r '.paraBlockDispatchedTo')

    if [ "$state" = "S_ERROR" -o "$height" = -1 ]; then
      restart "$uuid"
      workerArray[$key]=$(expr ${workerArray[$key]} + 1)
    else
      workerArray[$key]=0
    fi
  done

  isAlarm

  #check every 60s
  for i in $(seq 60 -1 1); do
    echo -ne "--- ${i}s 刷新 ---\r"
    sleep 1
  done
done
