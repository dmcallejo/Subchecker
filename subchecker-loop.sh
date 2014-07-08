#!/bin/bash
#
# USAGE: subchecker-loop.sh /home/pi/Downloads -log >> $LOG 
#
#	TODO:
#		- 720p, PROPER distinction (subs AND transmission) (example SoA)
#		# Compatibilidad "Espanol" (subs, lost girl 1x01) -- DONE UNDER TESTING
#		# Normalize S00E00 (caps) -- DONE UNTESTED
#		- Normalize show name (subtitulos.es) Caps'n'shit
#		- Percentage of subtitle completed.
#		- Add trackers to downloading torrents
#		- Subtitle 404 error
#		- Distinguish REPACKS when stopping torrents
#		# unrar AFTER torrent is downloaded -- DONE UNTESTED
#		- Check for '/' in episode names and substitute.
#		- sample mkv ignore


############ TRANSMISSION AUTH DATA ###############
LOGIN=pi
PASSWORD=raspberry
##################################################
LOG=/var/www/sublog


function loop {
until [ ! -s /tmp/subchecker/tree ]; do
	line=`head -n 1 /tmp/subchecker/tree`

	cond1=${line##*.}
    	cond1=`echo $cond1 | grep -i -w rar`
	if [[ -n $cond1 ]]; then
		#echo "tenemos un rar: "$line
		filename=$line
		unrarFile
	fi
	cond1=${line##*.}
	cond1=`echo $cond1 | grep -i -w mkv`
	if [[ -n $cond1 ]]; then
		#echo "tenemos un mkv: "$line
		if [[ -n `echo $line | grep [Ss][Aa][Mm][Pp][Ll][Ee]` ]]; then
			#echo "Ignoring sample mkv "
			sed 1d /tmp/subchecker/tree > /tmp/subchecker/tree2
			mv /tmp/subchecker/tree2 /tmp/subchecker/tree
			continue
		fi
		filename=$line
		parseMKV
	fi
	cond1=`echo $line | grep ./`
	if [[ -n $cond1 ]]; then
		#echo "Tenemos un directorio: "$line
		dir=${line//://}
	fi

	sed 1d /tmp/subchecker/tree > /tmp/subchecker/tree2
	mv /tmp/subchecker/tree2 /tmp/subchecker/tree
done
quit
}

function processMKV {
	echo -n "---> Processing $filename"
	ID=`transmission-remote 127.0.0.1:9091 --auth=$LOGIN:$PASSWORD -l | grep -i "$SHOW".$SE | sed 's/\([0-9][^0-9]\).*/\1/'`
	if [[ -z `echo $ID` ]] ; then
		echo
		echo "/!\\ Warning: Torrent not found in transmission list."
	else
		echo " ID:$ID"
		transmission-remote 127.0.0.1:9091 --auth=$LOGIN:$PASSWORD -t$ID --stop > /dev/null
	fi
	#
	# EXCEPTIONS
	#
	if [[ $SHOW == [Tt]ransporter.[Tt]he.[Ss]eries ]] ; then
		SHOW="Transporter:.The.Series"
	fi

	if [[ $SHOW == [Ff]aking.[Ii]t.2014 ]] ; then
		SHOW="Faking.It"
	fi
	#
	#
	#
	
	
	URL="http://www.subtitulos.es/"${SHOW//./-}/${SEASON//[Ss]/}x${EPISODE//[Ee]/}
	
	wget $URL -q -O /tmp/subchecker/html
	
    echo -n "Comprobando Castellano… "
	cat /tmp/subchecker/html | grep "Español (España)" -A 7 | grep "descargar</a>" > /tmp/subchecker/tmp
	if [[ -z `cat /tmp/subchecker/tmp` ]] ; then
			echo "Subtítulos no listos."
			if [[ -n `cat /tmp/subchecker/html | grep "Español (Latinoamérica)" -A 7 | grep "descargar</a>"` ]] ; then
				echo "Subtitulos en latinoamericano listos."
				echo
				SPA=$(cat /tmp/subchecker/html | grep "Español (Latinoamérica)" -A 6 | grep "href" | sed  's/^.*href="//' | sed 's/".*$//')
			elif [[ -n `cat /tmp/subchecker/html | grep "Español" -A 7 | grep "descargar</a>"` ]] ; then
				echo "Subtitulos en \"Español\" listos."
				echo
				SPA=$(cat /tmp/subchecker/html | grep "Español" -A 6 | grep "href" | sed  's/^.*href="//' | sed 's/".*$//')
			else
				return
			fi
	else
			if [[ -n `cat /tmp/subchecker/html | grep "Español (España)" -A 7 | grep '^\S*'"Completado "` ]] ; then
				SPA=$(cat /tmp/subchecker/html | grep "Español (España)" -A 7 | grep '^\S*'"Completado " -A 7 | grep "href" | sed  's/^.*href="//' | sed 's/".*$//')
				echo "Completados."
			else
				echo "Subtítulos CASI listos."
				echo `cat /tmp/subchecker/html | grep "Español (España)" -A 7 | grep '^\S*'"Completado "`
				echo
				return
			fi
		#SPA=$(cat /tmp/subchecker/html | grep "Español (España)" -A 6 | grep "href" | sed  's/^.*href="//' | sed 's/".*$//')
	fi
	
	echo -n "Comprobando Inglés… "
	cat /tmp/subchecker/html | grep "English" -A 7 | grep "descargar</a>" > /tmp/subchecker/tmp
	if [[ -z `cat /tmp/subchecker/tmp` ]] ; then
		cat /tmp/subchecker/html | grep "English" -A 7 | grep "actualizado</b></a>" > /tmp/subchecker/tmp
		if [[ -z `cat /tmp/subchecker/tmp` ]] ; then
			cat /tmp/subchecker/html | grep "English" -A 7 | grep "original</a>" > /tmp/subchecker/tmp
			if [[ ! -z `cat /tmp/subchecker/tmp` ]] ; then
				echo "Completados (Originales)."

			else
				echo "Subtítulos no listos."
				echo 
				return
			fi
		else
			echo "Completados (Actualizados)."
		fi
	else
		echo "Completados."
	fi
	# Ready to go!

	
	ENG=$(cat /tmp/subchecker/html | grep "English" -A 6 | grep "href" | sed  's/^.*href="//' | sed 's/".*$//')
	# ERRORES --> ENG=$(cat /tmp/subchecker/html | grep "English" -A 6 | grep "href" | sed  's/^.*href="//' | sed 's/" rel.*$//' | grep "original")

	TITLE=`grep "</h1>" < /tmp/subchecker/html`
	TITLE=${TITLE//* - /}
	TITLE=${TITLE//<*/}
	TITLE=`echo $TITLE | sed 's/ *$//g'`
	TITLE=`echo $TITLE | sed 's/^ *//g'`
	echo Titulo: $TITLE

	# DEBUG
	#echo $ENG
	#echo $SPA

	wget -q --referer=http://www.subtitulos.es/ "$SPA" -O "/tmp/subchecker/${filename:0:${#filename}-4}.spa.srt"
	wget -q --referer=http://www.subtitulos.es/ "$ENG" -O "/tmp/subchecker/${filename:0:${#filename}-4}.eng.srt"

	# Normalize SE
	SE=${SE//s/S}
	SE=${SE//e/E}

	

	#Al lio
	#echo "Filename: ""$dir${SHOW//./ } $SE - $TITLE".mkv
	mkvmerge -o "../${SHOW//./ } $SE - $TITLE".mkv -S --language 1:eng --track-name 1:English "$dir$filename" --sub-charset 0:WINDOWS-1252 --language 0:eng --track-name 0:English "/tmp/subchecker/${filename:0:${#filename}-4}.eng.srt" --sub-charset 0:WINDOWS-1252 --language 0:spa --track-name 0:Español /"tmp/subchecker/${filename:0:${#filename}-4}.spa.srt" --title "${SHOW//./ } $SE - $TITLE"


	if [ -e "../${SHOW//./ } $SE - $TITLE.mkv" ] ; then
		if [[ -n `echo $ID` ]] ; then
			transmission-remote 127.0.0.1:9091 --auth=$LOGIN:$PASSWORD -t$ID --remove-and-delete
			echo "--->COMPLETADO. Id: $ID. Torrent y datos eliminados."
		fi

		if [ -e  "$dir$filename" ] ; then
			rm "$dir$filename"
			if [ -e "$dir$filename" ] ; then
				echo "ERROR borrando el fichero manualmente."
			else
				echo "Archivo original eliminado manualmente."
			fi
		fi
	else
		echo "ERROR. No se ha encontrado el fichero ${SHOW//./ } $SE - $TITLE.mkv"
	fi
	echo
}


function parseMKV {
	#echo "Parsing file…" $filename
        SE=$(expr "$filename" : '.*\([sS][0-9][0-9][eE][0-9][0-9]-[eE][0-9][0-9]\).*')
        if [[ -z `echo $SE` ]] ; then 
                SE=$(expr "$filename" : '.*\([sS][0-9][0-9][eE][0-9][0-9]\).*')
        fi
        SEASON=$(expr "$filename" : '.*\([sS][0-9][0-9]\).*')
        EPISODE=$(expr "$filename" : '.*[Ss][0-9][0-9]\([eE][0-9][0-9]\).*')
        SHOW=${filename%.[sS][0-9][0-9][eE][0-9][0-9]*}
        dirtySHOW=$SHOW
        SHOW=${SHOW/*_}
        SHOW=${SHOW/*\ }

if [[ -z `echo $SEASON$EPISODE | grep '[Ss]..[Ee]..'` ]] ; then
	#echo "--->$filename: Not a show. Skipping. $SEASON$EPISODE"
	return
fi

if [[ $filename == $dirtySHOW ]] ; then
	echo "	-----> $filename: File already processed. Skipping <-----"
	return
fi
if [ -e "$dir$filename" ] ; then
	processMKV
	return
fi
echo "SHOULDN'T BE HERE BUT WHO CARES YOLO. $dir$filename"
}

function unrarFile {
	echo "---> Unrar file: $filename"
	target=`unrar l "$dir$filename" | grep -i .mkv`
	target=${target%.mkv*}.mkv
	target=`echo "$target" | sed 's/^ *//g'`
    
	SE=$(expr "$target" : '.*\([sS][0-9][0-9][eE][0-9][0-9]-[eE][0-9][0-9]\).*')
       	if [[ -z `echo $SE` ]] ; then 
       		SE=$(expr "$target" : '.*\([sS][0-9][0-9][eE][0-9][0-9]\).*')
       	fi
       	SEASON=$(expr "$target" : '.*\([sS][0-9][0-9]\).*')
	EPISODE=$(expr "$target" : '.*[Ss][0-9][0-9]\([eE][0-9][0-9]\).*')
        SHOW=${target%.[sS][0-9][0-9][eE][0-9][0-9]*}
	dirtySHOW=$SHOW
        SHOW=${SHOW/*_}
	SHOW=${SHOW/*\ }
	ID=`transmission-remote 127.0.0.1:9091 --auth=$LOGIN:$PASSWORD -l | grep -i "$SHOW".$SE | sed 's/\([0-9][^0-9]\).*/\1/'`

	# Checks if torrent has been fully downloaded.
	if [[ -z `echo $ID` ]] ; then
		echo "WTF IS THIS SHIT"
		return;
	fi
	if [[ -z `transmission-remote 127.0.0.1:9091 --auth $LOGIN:$PASSWORD -t$ID -i | grep "Percent Done: 100%"` ]] ; then
		echo "Torrent is not complete."
		return;
	fi

	unrar e "$dir$filename" "$fileRoot"	
	
	if [[ -z `echo $ID` ]] ; then
		echo "/!\\ Warning: Torrent not found in transmission list."
		echo "DEBUG: $SHOW".$SE
	else
		transmission-remote 127.0.0.1:9091 --auth=$LOGIN:$PASSWORD -t$ID --remove-and-delete
	fi

	#Restart Script:
	echo "/!\\WARNING: Restarting Script"
	cd $fileRoot
	ls -R > /tmp/subchecker/tree
	dir=""

}

function quit {
	if [ -e /tmp/subchecker/restart ] ; then
		rm /tmp/subchecker/restart
		#Restart Script:
        echo -n "/!\\	WARNING: Restarting Script. "
		date
        cd $fileRoot
        ls -R > /tmp/subchecker/tree
		dir=""
		loop
		return
	fi
	rm -R /tmp/subchecker
	if [[ log -eq 1 ]] ; then
		echo "--------------------------------------------------------"
		echo
		echo "Capítulos preparados: "
		echo "----------------------"
		cd $fileRoot
		ls ../*.mkv | grep " - " 
		echo
		df -h
	fi	
	exit
}

#################
#		#
#	LOOP	#
#		#
#################
if [ -e /tmp/subchecker/lock ] ; then
	#echo "Directory locked, already running. Exiting..."
	if [ ! -e /tmp/subchecker/restart ] ; then
		touch /tmp/subchecker/restart
		echo -n "/!\\	CRON CALL. Script will restart. "
		date
	fi
	exit
else
	mkdir /tmp/subchecker
	touch /tmp/subchecker/lock
	echo -n "" > $LOG
fi

# Parameters parse

if [[ $1 == -log ]] ; then
	echo "--------------------------------------------------------"
	date
	echo "--------------------------------------------------------"
	log=1
else

	if [ ! -z `echo $1` ] ; then
        fileRoot=$1
		cd $fileRoot
	fi

	if [[ $2 == -log ]] ; then
	echo "--------------------------------------------------------"
	date
	echo "--------------------------------------------------------"
	log=1
	fi
fi
ls -R > /tmp/subchecker/tree

loop
echo "Go home script, you're drunk"

until [ ! -s /tmp/subchecker/tree ]; do
	line=`head -n 1 /tmp/subchecker/tree`

	cond1=${line##*.}
    	cond1=`echo $cond1 | grep -i rar`
	if [[ -n $cond1 ]]; then
		#echo "tenemos un rar: "$line
		filename=$line
		unrarFile
	fi
	cond1=${line##*.}
	cond1=`echo $cond1 | grep -i mkv`
	if [[ -n $cond1 ]]; then
		#echo "tenemos un mkv: "$line
		filename=$line
		parseMKV
	fi
	cond1=`echo $line | grep ./`
	if [[ -n $cond1 ]]; then
		#echo "Tenemos un directorio: "$line
		dir=${line//://}
	fi

	sed 1d /tmp/subchecker/tree > /tmp/subchecker/tree2
	mv /tmp/subchecker/tree2 /tmp/subchecker/tree
done
quit
# sed 1d textfile remove first line
# head -n 1 textfile
