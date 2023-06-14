function replace_config_urls () {

    grep -rl "$USER_ISP" . | while read file
    do
      if grep -q "/var/www/$USER_ISP/data/www/" "$file"; then
        echo "Осуществляется замена в файле: $file"
        awk '{original = $0; change = gsub("'"\/var\/www\/$USER_ISP\/data\/www\/"'", "'"\/home\/$USER_CPANEL\/"'")}
             change {print "Замена в файле: " FILENAME "\nСтрока: " NR "\nСтарая строка: " original "\nНовая строка: " $0 "\n"}' "$file" | tee -a replace_paths.txt
        sed -i 's/\/var\/www\/'$USER_ISP'\/data\/www\//\/home\/'$USER_CPANEL'\//g' "$file"
      fi
    done
}