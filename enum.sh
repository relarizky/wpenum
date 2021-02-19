#!/usr/bin/env bash


set -o nounset   # abort on unset variables
set -o errexit   # abort on non-zero exit status
set -o pipefail  # not hiding error within pipes


readonly user_agent="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:85.0) Gecko/20100101 Firefox/85.0"
readonly output_dir="log"  # change it if you'd like to


banner() {
	clear

	echo "__          _______  ______"
	echo "\ \        / /  __ \|  ____|"
	echo " \ \  /\  / /| |__) | |__   _ __  _   _ _ __ ___"
	echo "  \ \/  \/ / |  ___/|  __| | '_ \| | | | '_ \` _ \\"
	echo "   \  /\  /  | |    | |____| | | | |_| | | | | | |"
 	echo "    \/  \/   |_|    |______|_| |_|\__,_|_| |_| |_|"
	echo -e "\n"
}


create_log() {
	local url="${1}"
	local user_list="${2}"

	if [ ! -d "${output_dir}" ]; then
		mkdir "${output_dir}"
	fi

	local domain=`echo "${url}" | grep --only-matching --perl-regexp --ignore-case '//[a-z0-9.-]+\.[a-z]{2,3}'`
	local domain=`echo "${domain}" | tr --delete "//"`

	for user in ${user_list}; do
		echo ${user} >> "${output_dir}/${domain}"
	done

	echo "[+] All found usernames are stored in ${output_dir}/${domain}"
}


enum_from_json() {
	local target="${1}/wp-json/wp/v2/users/"
	local request_body="$(curl --silent --user-agent ${user_agent} ${target})"
	local request_stat="$(curl --silent --head --user-agent ${user_agent} ${target})"
	local request_stat="$(echo ${request_stat} | head -1 | cut --delimiter ' ' --fields 2)"

	if [ "${request_stat}" != "200" ]; then
		echo "[-] Unable to find user from JSON";
	else
		local user_list="$(echo ${request_body} | jq '.[].slug' | tr --delete '\"')"
		local user_total="$(echo ${user_list} | wc -w)"
		echo "[+] Found ${user_total} usernames in /wp-json"
		create_log "${1}" "${user_list}"
	fi
}


enum_from_url() {
	local target="${1}";
	declare -a user_list;
	declare -i index=1;

	function get_user() {
		local user="$(echo ${1} | grep --perl-regexp --only-matching --ignore-case '/author/[a-z0-9-.]*/"')"
		local user="$(echo ${user} | cut --delimiter '/' --fields 3)"

		echo "${user}"
	}

	until [ ${index} -gt 10 ]; do
		local author="${target}/?author=${index}";
		local request_body="$(curl --include --location --silent --user-agent ${user_agent} ${author})"
		local found_user=$(get_user "${request_body}")

		if [ ! -z "${found_user}" ]; then
			user_list[${index}]=${found_user}
		fi

		index=$((${index}+1))
	done

	user_list="$(echo ${user_list[@]} | tr ' ' '\n' | sort -u)" # remove duplicate
	user_total="$(echo ${user_list} | tr ' ' '\n' | wc -w)"

	echo "[+] Found ${user_total} usernames in /author"

	create_log "${target}" "${user_list}"
}

main() {
	local target="${1}"

	filter_url() {
		local url="${1}"

		if [ ! -z `echo "${url}" | grep --perl-regexp --ignore-case '^http[s]*://'` ]; then
			echo 0  # return True
		else
			echo 1  # return False
		fi
	}

	if [ `filter_url "${target}"` -ne 0 ]; then
		echo "[-] Your given URL seems to be invalid."
		exit 1;
	fi

	echo "[+] Start scanning ${target}"
	enum_from_json "${target}"
	enum_from_url "${target}"
	echo "[+] Finished scanning."
}

banner

if [ $# -ne 1 ]; then
	echo "[+] Usage: $0 <url>"
	exit 0
fi

main "${1}"
