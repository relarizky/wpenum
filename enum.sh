#!/usr/bin/env bash


USER_AGENT="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:85.0) Gecko/20100101 Firefox/85.0";
DEFAULT_DIR="log";  # change it if you'd like to


function banner() {
	clear;

	echo "__          _______  ______";
	echo "\ \        / /  __ \|  ____|";
	echo " \ \  /\  / /| |__) | |__   _ __  _   _ _ __ ___";
	echo "  \ \/  \/ / |  ___/|  __| | '_ \| | | | '_ \` _ \\";
	echo "   \  /\  /  | |    | |____| | | | |_| | | | | | |";
 	echo "    \/  \/   |_|    |______|_| |_|\__,_|_| |_| |_|";
	echo -e "\n";
}


function create_log() {
	local user_list=$1;
	local domain=$(echo $2 | grep --perl-regexp --only-matching \
		--ignore-case '//[a-z0-9.-]+\.[a-z]{2,3}' \
		| tr -d '//');

	if [ ! -d ${DEFAULT_DIR} ]; then
		mkdir "${DEFAULT_DIR}";
	fi

	for user_name in ${user_list}; do
		echo ${user_name} >> "${DEFAULT_DIR}/${domain}";
	done

	echo "[+] all found usernames are saved in ${DEFAULT_DIR}/${domain}";
}


function enum_from_json() {
	local target="$1/wp-json/wp/v2/users/";
	local request_body=$(curl --silent --user-agent "${USER_AGENT}" "${target}");
	local request_stat=$(curl --silent --head \
		--user-agent "${USER_AGENT}" "${target}" \
		| head -1 | cut -f 2 -d ' ');

	if [ ${request_stat} -ne 200 ]; then
		echo "[-] Unable to find user from JSON";
	else
		local user_list=$(echo ${request_body} | jq '.[].slug' | tr -d '"');
		local total=`echo ${user_list} | wc -w`;

		echo "[+] found ${total} usernames in /wp-json";
		create_log "${user_list}" "$1";
	fi
}


function enum_from_url() {
	declare -a user_list;
	declare -i indeks1=1 indeks2=0;

	function get_user() {
		local user=$(echo $1 | grep --perl-regexp \
			--only-matching --ignore-case '/author/[a-z0-9-.]*/"' | \
			cut --delimiter="/" --fields=3);

		echo ${user};	 # returning found user
	}

	until [ ${indeks1} -gt 10 ]; do
		local target="$1/?author=${indeks1}";
		local request_body=$(curl --include --location \
			--silent --user-agent "${USER_AGENT}" "${target}");
		local found_user=$(get_user "${request_body}");

		for user in `echo ${found_user} | tr " " "\n"`; do
			user_list[${indeks2}]=${user};
			indeks2=`expr ${indeks2} + 1`;
		done

		indeks1=`expr ${indeks1} + 1`;
	done

	user_list=$(echo ${user_list[@]} | tr " " "\n" | sort -u);
	user_total=$(echo ${user_list} | tr " " "\n" | wc -w);

	echo "[+] found ${user_total} usernames in /author";

	create_log "${user_list}" "$1";
}


banner;


if [ $# -ne 1 ]; then
	echo "Usage: $0 <url>";
	exit 0;
fi


echo "[+] start scan $1";


enum_from_url $1;
enum_from_json $1;


echo "[+] Done.";
