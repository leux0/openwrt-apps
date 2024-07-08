#!/bin/sh

TIMEOUTS=60
ATDEVICE=/dev/ttyUSB3
CELLINFO=/tmp/cellinfo
LOCKFILE=/tmp/cellscanlock

ARFCN_TO_BAND() {
    local ARFCN=$1
    local BANDS=""

    # 4G LTE
	if [ $ARFCN -ge 0 ] && [ $ARFCN -le 41589 ]; then
		if [ $ARFCN -ge 0 ] && [ $ARFCN -le 599 ]; then
			BANDS="Band 1"
		elif [ $ARFCN -ge 1200 ] && [ $ARFCN -le 1949 ]; then
			BANDS="Band 3"
		elif [ $ARFCN -ge 2400 ] && [ $ARFCN -le 2649 ]; then
			BANDS="Band 5"
		elif [ $ARFCN -ge 3450 ] && [ $ARFCN -le 3799 ]; then
			BANDS="Band 8"
		elif [ $ARFCN -ge 36200 ] && [ $ARFCN -le 36349 ]; then
			BANDS="Band 34"
		elif [ $ARFCN -ge 37750 ] && [ $ARFCN -le 38249 ]; then
			BANDS="Band 38"
		elif [ $ARFCN -ge 38250 ] && [ $ARFCN -le 38649 ]; then
			BANDS="Band 39"
		elif [ $ARFCN -ge 38650 ] && [ $ARFCN -le 39649 ]; then
			BANDS="Band 40"
		elif [ $ARFCN -ge 39650 ] && [ $ARFCN -le 41589 ]; then
			BANDS="Band 41"
	fi
	# 以下是5G NR的
	elif [ $ARFCN -ge 422000 ] && [ $ARFCN -le 434000 ]; then
		BANDS="N1"
	elif [ $ARFCN -ge 361000 ] && [ $ARFCN -le 376000 ]; then
		BANDS="N3"
	elif [ $ARFCN -ge 185000 ] && [ $ARFCN -le 192000 ]; then
		BANDS="N8"
	elif [ $ARFCN -ge 499200 ] && [ $ARFCN -le 537999 ]; then
		BANDS="N41"
	elif [ $ARFCN -ge 620000 ] && [ $ARFCN -le 680000 ]; then
		BANDS="N78"
	elif [ $ARFCN -ge 693334 ] && [ $ARFCN -le 733333 ]; then
		BANDS="N79"
	# 5G NR重复频段检查
	elif [ $ARFCN -ge 158200 ] && [ $ARFCN -le 164200 ]; then
		BANDS="N20"
	fi
	if [ $ARFCN -ge 151600 ] && [ $ARFCN -le 160600 ]; then
		[ -n "$BANDS" ] && BANDS="${BANDS}/"
		BANDS="${BANDS}n28"
	fi

	if [ -z "$BANDS" ]; then
		BANDS="Unknown Band"
	fi

	echo "$BANDS"
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
		ARFCN=$(echo "$line" | awk -F ',' '{print $4}')
		BAND=$(ARFCN_TO_BAND $ARFCN)

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
