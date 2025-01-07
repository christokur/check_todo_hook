#!/usr/bin/env bash

for tflhcl in $(find . -name .tflint.hcl 2>/dev/null); do
  dir=$(dirname $tflhcl)
  cd $dir
  echo begin $PWD
  ignore=$dir
  while [ "$ignore" != "." -a "$ignore" != "/" ]; do
    [ -z "$(egrep $ignore .tflint.ignore 2>/dev/null)" ] || { ignore=""; break; }
    ignore=$(dirname $ignore);
  done
  [ -z "$ignore" ] || {
    format=$(egrep 'format\s*=\s+' .tflint.hcl 2>/dev/null | cut -d = -f 2 | cut -d ' ' -f 2 | tr -d '"')
    #echo format=$format
    tflint --recursive --filter=*.tf --minimum-failure-severity=warning --format=$format | while read line; do
      file=$(echo $line | cut -d : -f 1)
      #echo file=$file
      lnnr=$(echo $line | cut -d : -f 2)
      #echo lnnr=$lnnr
      if [ "$line" == "$file:" -o -z "$line" ] ; then
        echo $line
      else
        colm=$(echo $line | cut -d : -f 3)
        #echo colm=$colm
        rest=$(echo $line | cut -d : -f 4-10)
        #echo rest=$rest
        printf "%s:%03d:%d:%s\n" $file $((0+lnnr)) $((0+colm)) "$rest"
        #break
      fi
    done  | sort -n
    echo end $PWD;
  }
  cd -;
done
