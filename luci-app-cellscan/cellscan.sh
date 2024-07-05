#!/bin/ash

TIMEOUTS=60
ATDEVICE=/dev/ttyUSB3
CELLINFO=/tmp/cellinfo
LOCKFILE=/tmp/cellscanlock

earfcn_to_band() {
    local earfcn=$1
    local bands=""

    # 4G LTE
	if [ $earfcn -ge 0 ] && [ $earfcn -le 41589 ]; then
		if [ $earfcn -ge 0 ] && [ $earfcn -le 599 ]; then
			bands="Band 1"
		elif [ $earfcn -ge 1200 ] && [ $earfcn -le 1949 ]; then
			bands="Band 3"
		elif [ $earfcn -ge 2400 ] && [ $earfcn -le 2649 ]; then
			bands="Band 5"
		elif [ $earfcn -ge 3450 ] && [ $earfcn -le 3799 ]; then
			bands="Band 8"
		elif [ $earfcn -ge 36200 ] && [ $earfcn -le 36349 ]; then
			bands="Band 34"
		elif [ $earfcn -ge 37750 ] && [ $earfcn -le 38249 ]; then
			bands="Band 38"
		elif [ $earfcn -ge 38250 ] && [ $earfcn -le 38649 ]; then
			bands="Band 39"
		elif [ $earfcn -ge 38650 ] && [ $earfcn -le 39649 ]; then
			bands="Band 40"
		elif [ $earfcn -ge 39650 ] && [ $earfcn -le 41589 ]; then
			bands="Band 41"
	fi
	# 以下是5G NR的
	elif [ $earfcn -ge 422000 ] && [ $earfcn -le 434000 ]; then
		bands="N1"
	elif [ $earfcn -ge 361000 ] && [ $earfcn -le 376000 ]; then
		bands="N3"
	elif [ $earfcn -ge 185000 ] && [ $earfcn -le 192000 ]; then
		bands="N8"
	elif [ $earfcn -ge 499200 ] && [ $earfcn -le 537999 ]; then
		bands="N41"
	elif [ $earfcn -ge 620000 ] && [ $earfcn -le 680000 ]; then
		bands="N78"
	elif [ $earfcn -ge 693334 ] && [ $earfcn -le 733333 ]; then
		bands="N79"
	# 5G NR重复频段检查
	elif [ $earfcn -ge 158200 ] && [ $earfcn -le 164200 ]; then
		bands="N20"
	fi
	if [ $earfcn -ge 151600 ] && [ $earfcn -le 160600 ]; then
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

# 确认需要扫描哪种网络，4G和5G的排版大不相同所以分开了
echo "开始基站扫描......扫描需要${TIMEOUTS}秒"
echo -e 'at+qscan=3,0\r\n' > ${ATDEVICE}

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
		SCS_KHZ="15"
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
			"*")
				SCS_KHZ="未知"
                ;;
        esac

		# 根据 <载波频点号> 来判断 <频带>
		EARFCN=$(echo "$line" | awk -F ',' '{print $4}')
		BAND=$(earfcn_to_band $EARFCN)

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
