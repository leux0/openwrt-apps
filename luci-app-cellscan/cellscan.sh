#!/bin/ash

TIMEOUTS=60
ATDEVICE=/dev/ttyUSB3
CELLINFO=/tmp/cellinfo
LOCKFILE=/tmp/cellscanlock

freq_to_band() {
    local freq=$1
    local bands=""

    # 4G LTE
	if [ $freq -ge 0 ] && [ $freq -le 41589 ]; then
		if [ $freq -ge 0 ] && [ $freq -le 599 ]; then
			bands="Band 1"
		elif [ $freq -ge 1200 ] && [ $freq -le 1949 ]; then
			bands="Band 3"
		elif [ $freq -ge 2400 ] && [ $freq -le 2649 ]; then
			bands="Band 5"
		elif [ $freq -ge 3450 ] && [ $freq -le 3799 ]; then
			bands="Band 8"
		elif [ $freq -ge 36200 ] && [ $freq -le 36349 ]; then
			bands="Band 34"
		elif [ $freq -ge 37750 ] && [ $freq -le 38249 ]; then
			bands="Band 38"
		elif [ $freq -ge 38250 ] && [ $freq -le 38649 ]; then
			bands="Band 39"
		elif [ $freq -ge 38650 ] && [ $freq -le 39649 ]; then
			bands="Band 40"
		elif [ $freq -ge 39650 ] && [ $freq -le 41589 ]; then
			bands="Band 41"
	fi
	# 以下是5G NR的
	elif [ $freq -ge 422000 ] && [ $freq -le 434000 ]; then
		bands="N1"
	elif [ $freq -ge 361000 ] && [ $freq -le 376000 ]; then
		bands="N3"
	elif [ $freq -ge 185000 ] && [ $freq -le 192000 ]; then
		bands="N8"
	elif [ $freq -ge 499200 ] && [ $freq -le 537999 ]; then
		bands="N41"
	elif [ $freq -ge 620000 ] && [ $freq -le 680000 ]; then
		bands="N78"
	elif [ $freq -ge 693334 ] && [ $freq -le 733333 ]; then
		bands="N79"
	# 5G NR重复频段检查
	elif [ $freq -ge 158200 ] && [ $freq -le 164200 ]; then
		bands="N20"
	fi
	if [ $freq -ge 151600 ] && [ $freq -le 160600 ]; then
		[ -n "$bands" ] && bands="${bands}/"
		bands="${bands}n28"
	fi

	if [ -z "$bands" ]; then
		bands="Unknown Band"
	fi

	echo "$bands"
}

# 如果文件存在则代表正在扫描中，如果脚本正在扫描，则先停止脚本再删除该文件
if [ -e ${LOCKFILE} ]; then
	if kill -9 `cat ${LOCKFILE}`; then
		echo "Cell scanning is already Kill it."
		rm -f ${LOCKFILE}
	else
		echo "Removing stale lock file."
		rm -f ${LOCKFILE}
	fi
fi

# 清空保存扫描信息的文件并保存脚本运行的PID
echo -n > ${CELLINFO}
echo $$ > ${LOCKFILE}
PID=`cat ${LOCKFILE}`

echo "开始基站扫描......扫描需要${TIMEOUTS}秒"
echo -e 'at+qscan=3,1\r\n' > ${ATDEVICE}

timeout $TIMEOUTS cat ${ATDEVICE} | while read line
do
    case "$line" in "+QSCAN"*)
		# 根据 <MCC 移动国家代码> 和 <MNC 移动网络代码> 来判断运营商
        operatorCode=$(echo $line | awk -F ',' '{print $2$3}')
        case "$operatorCode" in
            "46000" | "46002" | "46007" | "46008" | "46020")
                operator="移动"
                ;;
            "46001" | "46006" | "46009")
                operator="联通"
                ;;
            "46003" | "46005" | "46011")
                operator="电信"
                ;;
            "46015")
                operator="广电"
                ;;
            *)
                operator="未知"
                ;;
        esac

        # 5G子载波间隔的取值：0=15kHz，1=30kHz，2=60kHz，3=120kHz，4=240kHz。LTE的子载波间隔通常为15KHz
		SCS=$(echo $line | awk -F ',' '{print $9}')
		case "$SCS" in
			"0")
				SCS_KHZ="15"
                ;;
			"1")
				SCS_KHZ="30"
                ;;
			"2")
				SCS_KHZ="60"
                ;;
			"3")
				SCS_KHZ="120"
                ;;
			"4")
				SCS_KHZ="240"
                ;;
			*)
				SCS_KHZ="--"
                ;;
        esac

		# 根据 <载波频点号> 来判断 <频带>
		FREQ=$(echo "$line" | awk -F ',' '{print $4}')
		BAND=$(freq_to_band $FREQ)

		# 将扫描到的信息格式化记录到文件，"网类型, 运营商, 频段, 频点号, 小区号, 信号强度, 接收质量, 载波间隔\n"
		echo $line | awk -F ',' -v operator="$operator" -v SCS_KHZ="$SCS_KHZ" -v BAND="$BAND" '{printf("%s,%s,%s,%s,%s,%s,%s,%s\n", $1, operator, BAND, $4, $5, $6, $7, SCS_KHZ)}' >> ${CELLINFO}
    esac
    case "$line" in *"OK"*)
		# 删除锁文件后停止脚本并退出
        rm -f ${LOCKFILE}
        kill -9 $PID
        exit 0
    esac
done

rm -f ${LOCKFILE}
