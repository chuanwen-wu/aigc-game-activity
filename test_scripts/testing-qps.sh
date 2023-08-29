#!/bin/bash

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 ingress_url request_count timeInterval"
    exit 1
fi

url=$1
batchCount=$2
timeInterval=$3
scriptFile=inference-sample.py
#source ../venv/bin/activate
do_one_inference()
{
    idx=$1
    echo $idx
    currentTime=$(date "+%H:%M:%S")
    startTs=$(date +%s)
    python $scriptFile $url
    endTs=$(date +%s)
    endTime=$(date "+%H:%M:%S")
    echo "[$endTime] [$idx] start at $currentTime, time taken: $((endTs-startTs))"
}

# 每批任务执行时间间隔，/秒
# timeInterval=0
# 总共任务批数
# batchCount=30
# 每批任务的请求数
batchSize=1

echo [$(date "+%H:%M:%S")] Start testing...
t1=$(date +%s)
for j in $(seq 1 $batchCount);do
    for i in $(seq 1 $batchSize);do
        do_one_inference ${j}_${i} &
    done
    if [[ $timeInterval -gt 0 ]];then
        echo "sleep ${timeInterval}..."
        sleep ${timeInterval}
    fi
done
wait
t2=$(date +%s)
dt=$((t2-t1))
qps=$(echo "scale=3; $batchCount*$batchSize/$dt" | bc)
timeTaken=$(echo "scale=2; 1/$qps" | bc)
echo [$(date "+%H:%M:%S")] End testing
echo "Total cost time: $dt, timeInterval=$timeInterval, batchCount=$batchCount, batchSize=$batchSize, QPS=$qps, avergeTimeTaken=$timeTaken"