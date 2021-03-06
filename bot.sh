#!/bin/bash
source variaveis.sh

ct=0
curl -s $apiurl/getMe 2>&1 >/dev/null

envia(){
	source variaveis.sh
	curl -s -X POST "$apiurl/sendMessage" \
	-F text="$*" -F parse_mode="markdown" \
	-F chat_id=$CHATID 2>&1 >/dev/null 
}

parametros(){
	local mensagem="Parâmetros:
BTC: > $BTCMAX e < $BTCMIN
LTC: > $LTCMAX e < $LTCMIN
CHECAGEM A CADA $INTERVALO minutos
ALERTA SE DIFERENÇA MAIOR QUE $PORCENTAGEM %
"
	envia "$mensagem"
}

parametros

isAdmin(){
	grep -q $1 <<< "${ADMINS[@]}"
}

isValidCommand(){
	grep -Eoq "$COMANDOS" <<< "$1"
}

formata(){
	LC_ALL=pt_BR.utf-8 numfmt --format "%'0.2f" ${1/./,}
}

coin() {
	coin=$1
	(( $# == 2 )) \
		&& qtd=$2 \
		|| qtd=0
	json="$(curl -sL $coinmarketcap/$coin \
	| jq -r '"\(.[].price_usd) \(.[].price_btc) \(.[].percent_change_1h) \(.[].percent_change_24h) \(.[].symbol)"')"
	echo "$json" | jq '.error' 2>/dev/null && envia "${coin^^} não encontrada na coinmarketcap" || {
	read usd btc change1h change24h symbol <<< $json
	[[ $qtd =~ [^[:digit:]\.] ]] && qtd=0
	[ "$qtd" == "0" ] && local msg="\`\`\`
Cotação CoinMarketCap para ${symbol^^}:
USD $(formata $usd)
BTC $btc
24h: $change24h
1h: $change1h
\`\`\`
" || {
	read foxbitsell foxbithigh foxbitlow <<< $(curl -s "$foxbiturl" |\
	jq -r '"\(.sell) \(.high) \(.low)"')
	read mbtc btchigh btclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read maior menor <<< $(echo "${foxbitsell/.*/},Foxbit
${mbtc/.*/},MercadoBitCoin" | sort -nrk1 -t, | tr '\n' ' ')
	IFS=, read reais maiorexchange <<< $maior
	local msg="\`\`\`
${qtd} ${symbol^^} valem:
${symbol^^} $btc (USD $(formata $usd))
USD $(formata $(echo "$usd*$qtd" | bc ))
BRL $(formata $(echo "$reais*$btc*$qtd" | bc))
BTC $(echo "$btc*$qtd" | bc)
24h: $change24h
1h: $change1h
\`\`\`"
}
	envia "$msg"
	}
}

ajuda(){
	local mensagem="Comandos aceitos:
*/ltcmax 170*
*/ltcmin 110*
*/btcmax 9500*
*/btcmin 8000*
*/intervalo 5*
*/porcentagem 4.01*
*/parametros*
*/cotacoes*
*/coin moeda*
*/coin moeda 1.3*
*/adiciona moeda 30.3*
*/remove moeda*
*/consulta*
"
	envia "$mensagem"
}

read offset username command <<< $(curl -s  -X GET "$apiurl/getUpdates"  |\
jq -r '"\(.result[].update_id) \(.result[].message.from.username) \(.result[].message.text)"' |\
tail -1)

export offset
export command

mensagem (){
	source variaveis.sh
	read foxbitsell foxbithigh foxbitlow <<< $(curl -s "$foxbiturl" |\
	jq -r '"\(.sell) \(.high) \(.low)"')
	dolarbb=$(wget -qO- https://internacional.bb.com.br/displayRatesBR.bb | grep -iEA1 "real.*Dólar" | tail -1 |\
	grep -Eo "[0-9]\.[0-9]+")
	xapo=$(printf "%0.2f" $(curl -sL $coinmarketcap/bitcoin | jq -r '"\(.[].price_usd)"'))
	dolar2000=$(echo "scale=4; ${dolarbb:-0}*1.0844" | bc)
	dolar3000=$(echo "scale=4; ${dolarbb:-0}*1.0664" | bc)
	dolar4000=$(echo "scale=4; ${dolarbb:-0}*1.0574" | bc)
	read btc btchigh btclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read ltc ltchigh ltclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker_litecoin |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read maior menor <<< $(echo "${foxbitsell/.*/},Foxbit
${btc/.*/},MercadoBitCoin" | sort -nrk1 -t, | tr '\n' ' ')
	IFS=, read maiorvlr maiorexchange <<< $maior
	IFS=, read menorvlr menorexchange <<< $menor
	diff=$(echo "scale=3; (($maiorvlr/$menorvlr)-1)*100" | bc | grep -Eo "[0-9]{1,}\.[0-9]")
	msg="*Bitcoin: *
*MercadoBTC:* R\$ $btc
(*>* $btchigh / *<* $btclow) Var: $(echo "scale=5; ($btchigh/$btclow-1)*100"|bc|\
grep -Eo "[0-9]*\.[0-9]{2}")%
*FoxBit:* R\$ $foxbitsell
(*>* $foxbithigh / *<* $foxbitlow) Var: $(echo "scale=4; ($foxbithigh/$foxbitlow-1)*100"|bc|\
grep -Eo "[0-9]*\.[0-9]{2}")%

*( Diferença: $maiorexchange ${diff:-0}% mais caro que $menorexchange )*

*Xapo:* USD $xapo

*Custo Dolar BB -> Xapo*: 
*USD 2000*: $dolar2000
*USD 3000*: $dolar3000
*USD 4000*: $dolar4000
"
	rate=$(echo "scale=2; $maiorvlr/$xapo" |bc)
	msg+="
*$maiorexchange/Xapo:* $rate
"
	msg+="
*Litecoin:* R\$ $ltc
(*>* $ltchigh / *<* $ltclow) Var: $(echo "scale=4; ($ltchigh/$ltclow-1)*100"|bc|\
grep -Eo "[0-9]*\.[0-9]{2}")%
"
	(( ${#msg} > 2 )) && { 
		envia "$msg"
	}
	[ -s $(date "+%Y%m%d").dat ] && {
		[ -s $(date "+%Y%m%d" --date="1 day ago").dat ] \
		&& cat $(date "+%Y%m%d" --date="1 day ago").dat >> /historico.dat
		maior=$(cat $(date "+%Y%m%d").dat | grep -Eo "[0-9]{3,}"| sort -n | tail -1)
		menor=$(cat $(date "+%Y%m%d").dat | grep -Eo "[0-9]{3,}"| sort -n | head -1)
		sed -i "s/set yrange.*/set yrange [ $((${menor/.*/}*95/100)):$((${maior/.*/}*105/100))]/g" geraimagem.pb
		gnuplot -c geraimagem.pb $(date "+%Y%m%d").dat > out.png
		idphoto=$(curl -s -X POST "$apiurl/sendPhoto" -F chat_id=$CHATID -F photo=@out.png |\
		jq -r '.result.photo[] | .file_id' | tail -1)
	}
}

mensagem

alerta(){
	valorhigh=$1
	valormin=$2
	valoraferido=$3
	exchangemax=$4
	exchangemin=$5
	exchange=$6
	if (( ${valoraferido/.*/} != 0 )); then
		(( ${valoraferido/.*/} > ${valorhigh} )) ||\
		(( ${valoraferido/.*/} < ${valormin} )) && {
			msg+="*${exchange}:* R\$ $valoraferido
"
			(( ${exchangemax/.*/} > 0 )) && {
				msg+="(*Max* R\$ $exchangemax / *Min* R\$ $exchangemin)
Δ% na $exchange: $(echo "scale=4; ($exchangemax/$exchangemin-1)*100"|bc|grep -Eo "[0-9]*\.[0-9]{2}")% 
"
			}
		}
	fi
}

adiciona(){
	(( $# != 3 )) && exit 1;
	local dono=$3
	local coin=${1^^}
	local quantidade=$2
	touch $dono.coins
	[[ $quantidade =~ [^[:digit:]\.-] ]] || {
		json="$(curl -sL $coinmarketcap/$coin \
		| jq -r '"\(.[].price_usd) \(.[].price_btc) \(.[].percent_change_1h) \(.[].percent_change_24h) \(.[].symbol)"')"
		echo "$json" | jq '.error' 2>/dev/null && envia "${coin^^} não encontrada na coinmarketcap" || {
			grep -qi "^$coin " $dono.coins && {
				read moeda valor <<< $(grep -i "$coin " $dono.coins);
				quantidade=$(echo "$valor+$quantidade"| bc)
				sed -i "s/$coin .*/$coin $quantidade/g" $dono.coins
				envia "Quantidade de $coin atualizada para $quantidade para @$dono"
			} || {
				echo "${coin} $quantidade" >> $dono.coins
				envia "$quantidade $coin adicionada para @$dono"
			}
			coin $coin $quantidade
		}
	}
}

remove(){
	dono=$2
	moeda=${1^^}
	touch $dono.coins
	grep -q "^$moeda " $dono.coins && {
		sed -i "/$moeda/d" $dono.coins
		envia "$moeda removida de @$dono"
	} || envia "@$dono não tem $moeda"
}

consulta(){
	dono=$1
	envia "Consultando moedas de @$dono"
	read foxbitsell foxbithigh foxbitlow <<< $(curl -s "$foxbiturl" |\
	jq -r '"\(.sell) \(.high) \(.low)"')
	read mbtc btchigh btclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	read maior menor <<< $(echo "${foxbitsell/.*/},Foxbit
	${mbtc/.*/},MercadoBitCoin" | sort -nrk1 -t, | tr '\n' ' ')
	IFS=, read reais maiorexchange <<< $maior
	msg=
	totalreais=0
	totaldolares=0
	totalbtc=0
	while read coin qtd; do
		json="$(curl -sL $coinmarketcap/$coin |\
		jq -r '"\(.[].price_usd) \(.[].price_btc) \(.[].percent_change_1h) \(.[].percent_change_24h) \(.[].symbol)"')"
		echo "$json" | jq '.error' 2>/dev/null \
		&& envia "${coin^^} não encontrada na coinmarketcap" \
		|| {
			read usd btc change1h change24h symbol <<< $json
			reaist=$(echo "$reais*$btc*$qtd" | bc)
			dolares=$(echo "$usd*$qtd" | bc)
			totalreais=$(echo "scale=2; $totalreais+$reaist" | bc);
			totaldolares=$(echo "scale=2; $totaldolares+$dolares" | bc);
			totalbtc=$(echo "$totalbtc+$btc*$qtd"|bc)
			local msg+="\`\`\`
=========================
${qtd} ${symbol^^} valem:
${symbol^^} $btc (USD $(formata $usd))
USD $(formata $dolares)
BRL $(formata $reaist)
BTC $(echo "$btc*$qtd" | bc)
24h: $change24h
1h: $change1h
\`\`\`
"
		}
	done < $dono.coins
	envia "$msg"
	stack="Totais para @${dono}:
\`\`\`
USD $(formata $totaldolares)
BRL $(formata $totalreais)
BTC ${totalbtc}\`\`\`"
	envia "$stack"
	
}

commandlistener(){
	atualizavar() {
		sed -i "s%$1.*%$1=\"$2\"%g" variaveis.sh
	}
	last=oe
	while : ; do
		source variaveis.sh
		for comando in $(curl -s  -X POST --data "offset=$((offset+1))" "$apiurl/getUpdates" |\
		jq -r '"\(.result[].update_id) \(.result[].message.from.username) \(.result[].message.text)"'|\
		sed 's/ /|/g' | sort | uniq); do
			read offset username command <<< $(echo $comando | sed 's/|/ /g')
			shopt -s extglob
			isAdmin "$username" && {
				command=${command%%@*}
				isValidCommand "$command" && {
					source variaveis.sh
					[ "$command" != "$last" ] && {
						echo $offset - @$username - $command - $last >> comandos.log
						case $command in 
							/ltcmax*) (( ${command/* /} != $LTCMAX )) && {
								envia "@${username}, setando *LTCMAX* para ${command/* /}";
								atualizavar LTCMAX ${command/* /}; 
								atualizavar last "$command";
							};;
							/ltcmin*) (( ${command/* /} != $LTCMIN )) && {
								envia "@${username}, setando *LTCMIN* para ${command/* /}";
								atualizavar LTCMIN ${command/* /};
								atualizavar last "$command"; 
							};;
							/btcmax*) (( ${command/* /} != $BTCMAX )) && {
								envia "@${username}, setando *BTCMAX* para ${command/* /}";
								atualizavar BTCMAX ${command/* /};
								atualizavar last "$command";
							};;
							/btcmin*) (( ${command/* /} != $BTCMIN )) && {
								envia "@${username}, setando *BTCMIN* para ${command/* /}";
								atualizavar BTCMIN ${command/* /};
								atualizavar last "$command";
							};;
							/intervalo*) [ "${command/* /}" != "$INTERVALO" ] && {
								envia "@${username}, setando *intervalo* para ${command/* /} minutos";
								atualizavar INTERVALO ${command/* /};
								atualizavar last "$command";
							};;
							/porcentagem*) [ "${command/* /}" != "$PORCENTAGEM" ] && {
								envia "@${username}, setando *porcentagem* para ${command/* /}%";
								atualizavar PORCENTAGEM ${command/* /};
								atualizavar last "$command";
							};;
							/coin*) [ "${command}" != "$last" ] && { 
								coin ${command/\/coin /};
								atualizavar last "$command"; };;
							/cotacoes) mensagem; 
								atualizavar last "$command";;
							/parametros) parametros $username; 
								atualizavar last "$command";;
							/help) ajuda $username; 
								atualizavar last "$command";;
							/adiciona*) adiciona ${command/\/adiciona /} $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
							/remove*) remove ${command/\/remove /} $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
							/consulta) consulta $username;
								command="$command $username";
								echo $command;
								atualizavar last "$command";;
						esac
					}
				}
			}
		done
	sleep 10s
	done
}

commandlistener &

while : 
do
	dolar=$(curl -s "https://finance.google.com/finance/converter?a=1&from=USD&to=BRL&meta=ei%3DJCL7WfnFL428e6vMn5AL"|grep result | grep -Eo "[0-9]\.[0-9]+" || echo $dolar)
	let ct+=1
	(( ct % 12 == 0 )) && { mensagem; sed -i "s/last=.*/last=oe/g" variaveis.sh ; }
	sleep ${INTERVALO}m
	source variaveis.sh
	msg=
	
	tmp=$(curl -sL $coinmarketcap/bitcoin | jq -r '"\(.[].price_usd)"' )
	xapo=$(printf "%0.2f " ${tmp:-$xapo})
	tmp=$(wget -qO- $mbtc/ticker |jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"')
	read btc btchigh btclow <<< $(printf "%0.2f " ${tmp:-$btc $btchigh $btclow})
	read ltc ltchigh ltclow <<< $(printf "%0.2f " $(wget -qO- $mbtc/ticker_litecoin |\
	jq -r '"\(.ticker.last) \(.ticker.high) \(.ticker.low)"'))
	tmp=$(curl -s "https://api.blinktrade.com/api/v1/BRL/ticker?crypto_currency=BTC" | jq -r '"\(.sell) \(.high) \(.low)"')
	read foxbitsell foxbithigh foxbitlow <<< ${tmp:-$foxbitsell $foxbithigh $foxbitlow}
	read maior menor <<< $(echo "${foxbitsell/.*/},Foxbit
${btc/.*/},MercadoBitCoin" | sort -nrk1 -t, | tr '\n' ' ')
	IFS=, read maiorvlr maiorexchange <<< $maior
	IFS=, read menorvlr menorexchange <<< $menor
	diff=$(echo "scale=3; (($maiorvlr/$menorvlr)-1)*100" | bc | grep -Eo "[0-9]{1,}\.[0-9]")
	
	alerta ${BTCMAX} ${BTCMIN} ${btc:-0} ${btchigh:-0} ${btclow:-0} MercadoBitcoin
	alerta ${BTCMAX} ${BTCMIN} ${foxbitsell:-0} ${foxbithigh:-0} ${foxbitlow:-0} FoxBit
	alerta ${LTCMAX} ${LTCMIN} ${ltc:-0} ${ltchigh:-0} ${ltclow:-0} "MercadoBitcoin(Litecoin)"

	rate=$(echo "scale=2; $maiorvlr/$xapo" |bc)
	rate=${rate:-3}
	btcusd=$(echo "scale=2; $xapo*$dolar"|bc)
	(( $(echo "${rate} >= ${PORCENTAGEM}"|bc) == 1 )) && {
		msg+="
*$maiorexchange/Xapo:* $rate ($btc/$xapo)"
	}
	diff=${diff:-0}
	(( $(echo "${diff} >= ${PORCENTAGEM}"|bc) == 1 )) && {
		msg+="
*$maiorexchange ($maiorvlr) ${diff}% mais caro que $menorexchange ($menorvlr)*
"
	}
	(( ${#msg} > 2 )) && {
		envia "$msg"
	}
	[ ! -s $(date "+%Y%m%d").dat ] && echo "##hora valor" > $(date "+%Y%m%d").dat
	read gmbtc gfoxbit btcusd <<< "${btc:-0} ${foxbitsell:-0} ${btcusd:-0}"
	echo "$(date "+%H:%M:%S") ${gmbtc/.*/} ${gfoxbit/.*/} ${btcusd/.*/}" >> $(date "+%Y%m%d").dat
done

