#! /bin/bash

#------------------------------------------#
#              LDAP2PostfixMap             #
#------------------------------------------#
#                                          #
#  Script that updates a Postfix virtual   #
#         map with emails on LDAP          #
#                                          #
#              Yvan Godard                 #
#          godardyvan@gmail.com            #
#                                          #
#        Version 0.2 -- may, 29 2015       #
#             Under Licence                #
#     Creative Commons 4.0 BY NC SA        #
#                                          #
#          http://goo.gl/9FauYh            #
#                                          #
#------------------------------------------#

# Variables initialisation
VERSION="Ldap2PostfixMap v0.2 - 2013, Yvan Godard [godardyvan@gmail.com]"
help="no"
SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)
DNBASE=""
VIRTUAL_MAP_FILE=""
VIRTUAL_MAP_FILE_NEW=$(mktemp /tmp/ldap2postfixmap_mapfilenew.XXXXX)
VIRTUAL_DOMAIN_RELAYED=""
LDAP_SERVER_URL="ldap://127.0.0.1"
DN_USER_BRANCH="cn=users"
LDAPGROUP_OBJECTCLASS="allusers"
LDAPGROUP=""
LDAPADMIN_UID=""
WITH_LDAP_BIND="no"
LDAPADMIN_PASS=""
POSTMAP_COMMAND="/usr/sbin/postmap"
MAIN_DOMAIN=""
MAIN_DOMAIN_DEFINED="no"
EMAIL_REPORT="nomail"
EMAIL_LEVEL=0
LOG="/var/log/ldap2postfixmap.log"
LOG_ACTIVE=0
EMAIL_ADDRESS=""
LOG_TEMP=$(mktemp /tmp/ldap2postfixmap_log.XXXXX)
LIST_USERS=$(mktemp /tmp/ldap2postfixmap_users.XXXXX)
LIST_DUPLICATED_EMAILS=$(mktemp /tmp/ldap2postfixmap_duplicatedemails.XXXXX)
DUPLICATED_EMAILS=0

help () {
	echo -e "$VERSION\n"
	echo -e "This tool is designed to create/update a Postifx virtual map with addresses from a LDAP group or alls users on LDAP."
	echo -e "It works both with LDAP groups defined by objectClass posixGroup or groupOfNames."
	echo -e "The domain name of virtual addresses must be defined in /etc/postfix/main.cf as (e.g. as 'virtual_alias_domain')"
	echo -e "and the Postfix map filename must be defined as 'virtual_alias_maps' in /etc/postfix/main.cf."
	echo -e "\nDisclamer:"
	echo -e "This tool is provide without any support and guarantee."
	echo -e "\nSynopsis:"
	echo -e "./$SCRIPT_NAME [-h] | -d <base namespace> -f <map filename> -v <virtual domain relayed>" 
	echo -e "                     [-s <LDAP server>] [-u <relative DN of user banch>]"
	echo -e "                     [-t <LDAP group objectClass>] [-g <relative DN of LDAP group>]"
	echo -e "                     [-a <LDAP admin UID>] [-p <LDAP admin password>] [-c <postmap command>]"
	echo -e "                     [-D <main domain>] [-e <email report option>] [-E <email address>] [-j <log file>]"
	echo -e "\n\t-h:                             prints this help then exit"
	echo -e "\nMandatory options:"
	echo -e "\t-d <base namespace>:              the base DN for each LDAP entry (e.g.: 'dc=server,dc=office,dc=com')"
	echo -e "\t-f <map filename>:                the full name of Postfix map filename (e.g.: '/etc/postfix/virtual_domain1')"
	echo -e "\t-v <virtual domain relayed>:      the domain that must be relayed with or without '@' (e.g.: '@myvirtualdomain.com' or 'my.virtual_domain.com')"
	echo -e "\nOptional options:"
	echo -e "\t-s <LDAP server>:                 the LDAP server LDAP_SERVER_URL (default: '${LDAP_SERVER_URL}')"
	echo -e "\t-u <relative DN of user banch>:   the relative DN of the LDAP branch that contains the users (e.g.: 'cn=allusers', default: '${DN_USER_BRANCH}')"
	echo -e "\t-t <LDAP group objectClass>:      the type of group you want to sync, must be 'posixGroup' or 'groupOfNames',"
	echo -e "\t                                  if unset, all users in LDAP user branch will be treated."	
	echo -e "\t-g <relative DN of LDAP group>:   the relative DN of the LDAP group to sync to Mailman list (e.g.: 'cn=mygroup,cn=groups' or 'cn=mygroup,ou=lists'),"
	echo -e "\t                                  must be filled if '-t' is used. "
	echo -e "\t-a <LDAP admin UID>:              LDAP administrator UID, if bind is needed to access LDAP (e.g.: 'diradmin')"
	echo -e "\t-p <LDAP admin password>:         the password of the LDAP administrator (asked if missing)"
	echo -e "\t-c <postmap command>:             the full name of 'postmap' command (default: '${POSTMAP_COMMAND}')"
	echo -e "\t-D <main domain>:                 main domain to map to if the user has multiple email addresses registered in the LDAP, with or without '@' (e.g.: 'myrealdoamain.fr')"
	echo -e "\t-e <email report option>:         settings for sending a report by email, must be 'onerror', 'forcemail' or 'nomail' (default: '${EMAIL_REPORT}')"
	echo -e "\t-E <email address>:               email address to send the report (must be filled if '-e forcemail' or '-e onerror' options is used)"
	echo -e "\t-j <log file>:                    enables logging instead of standard output. Specify an argument for the full path to the log file"
	echo -e "\t                                  (e.g.: '${LOG}') or use 'default' (${LOG})"
	exit 0
}

error () {
	echo -e "\n*** Error ***"
	echo -e "Error ${1}: ${2}"
	echo -e "\n"${VERSION}
	alldone ${1}
}

alldone () {
	# Redirect standard outpout
	exec 1>&6 6>&-
	# Logging if needed 
	[ $LOG_ACTIVE -eq 1 ] && cat $LOG_TEMP >> $LOG
	# Print current log to standard outpout
	[ $LOG_ACTIVE -ne 1 ] && cat $LOG_TEMP
	[ $EMAIL_LEVEL -ne 0 ] && [ $1 -ne 0 ] && cat $LOG_TEMP | mail -s "[ERROR : ldap2postfixmap.sh] on $(hostname)" ${EMAIL_ADDRESS}
	[ $EMAIL_LEVEL -eq 2 ] && [ $1 -eq 0 ] && cat $LOG_TEMP | mail -s "[OK : ldap2postfixmap.sh] on $(hostname)" ${EMAIL_ADDRESS}
	# Remove temp files
	rm -R /tmp/ldap2postfixmap*
	exit ${1}
}

optsCount=0

while getopts "hd:f:v:s:u:t:g:a:p:c:D:e:E:j:" OPTION
do
	case "$OPTION" in
		h)	help="yes"
						;;
		d)	DNBASE=${OPTARG}
			let optsCount=$optsCount+1
						;;
		f)	VIRTUAL_MAP_FILE=${OPTARG}
			let optsCount=$optsCount+1
						;;
		v)	VIRTUAL_DOMAIN_RELAYED=${OPTARG}
			let optsCount=$optsCount+1
						;;
	    s) 	LDAP_SERVER_URL=${OPTARG}
						;;
		u) 	DN_USER_BRANCH=${OPTARG}
						;;
		t)	LDAPGROUP_OBJECTCLASS=${OPTARG}
                        ;;
		g)	LDAPGROUP=${OPTARG}
                        ;;
		a)	LDAPADMIN_UID=${OPTARG}
			[[ ${LDAPADMIN_UID} != "" ]] && WITH_LDAP_BIND="yes"
						;;
		p)	LDAPADMIN_PASS=${OPTARG}
                        ;;
        c)	POSTMAP_COMMAND=${OPTARG}
                        ;;
		D)	MAIN_DOMAIN=${OPTARG}
			MAIN_DOMAIN_DEFINED="yes"
			            ;;
        e)	EMAIL_REPORT=${OPTARG}
                        ;;                             
        E)	EMAIL_ADDRESS=${OPTARG}
                        ;;
        j)	[ $OPTARG != "default" ] && LOG=${OPTARG}
			LOG_ACTIVE=1
                        ;;
	esac
done

if [[ ${optsCount} != "3" ]]
	then
        help
        alldone 1
fi

if [[ ${help} = "yes" ]]
	then
	help
fi

if [[ ${WITH_LDAP_BIND} = "yes" ]] && [[ ${LDAPADMIN_PASS} = "" ]]
	then
	echo "Password for $LDAPADMIN_UID,$DN_USER_BRANCH,$DNBASE?" 
	read -s LDAPADMIN_PASS
fi

# Redirect standard outpout to temp file
exec 6>&1
exec >> $LOG_TEMP

# Start temp log file
echo -e "\n****************************** `date` ******************************\n"
echo -e "$0 started for:"
echo -e "\t-f <map filename>:           ${VIRTUAL_MAP_FILE}"
echo -e "\t-v <virtual domain relayed>: ${VIRTUAL_DOMAIN_RELAYED}"

# Test of sending email parameter and check the consistency of the parameter email address
if [[ ${EMAIL_REPORT} = "forcemail" ]]; then
	EMAIL_LEVEL=2
	if [[ -z $EMAIL_ADDRESS ]]; then
		echo -e "You used option '-e ${EMAIL_REPORT}' but you have not entered any email info.\n\t-> We continue the process without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADDRESS}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]; then
    		echo -e "This address '${EMAIL_ADDRESS}' does not seem valid.\n\t-> We continue the process without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} = "onerror" ]]; then
	EMAIL_LEVEL=1
	if [[ -z $EMAIL_ADDRESS ]]; then
		echo -e "You used option '-e ${EMAIL_REPORT}' but you have not entered any email info.\n\t-> We continue the process without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADDRESS}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]; then	
    		echo -e "This address '${EMAIL_ADDRESS}' does not seem valid.\n\t-> We continue the process without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} != "nomail" ]]; then
	echo -e "\nOption '-e ${EMAIL_REPORT}' is not valid (must be: 'onerror', 'forcemail' or 'nomail').\n\t-> We continue the process without sending email."
	EMAIL_LEVEL=0
elif [[ ${EMAIL_REPORT} = "nomail" ]]; then
	EMAIL_LEVEL=0
fi

# Verification of LDAPGROUP_OBJECTCLASS parameter
[[ ${LDAPGROUP_OBJECTCLASS} != "allusers" ]] && [[ ${LDAPGROUP_OBJECTCLASS} != "posixGroup" ]] && [[ ${LDAPGROUP_OBJECTCLASS} != "groupOfNames" ]] && error 1 "Parameter '-t ${LDAPGROUP_OBJECTCLASS}' is not correct.\n-t must be 'posixGroup' or 'groupOfNames'"
[[ ${LDAPGROUP_OBJECTCLASS} != "allusers" ]] && [[ ${LDAPGROUP} = "" ]] && error 1 "Parameter '-t ${LDAPGROUP_OBJECTCLASS}' is not used but -g is empty.\n-g  must be filled with group name."

# Verification of LDAP_SERVER_URL parameter
[[ ${LDAP_SERVER_URL} = "" ]] && echo -e "You used option '-s' but you have not entered any LDAP url. Wi'll try to continue with url 'ldap://127.0.0.1'" && LDAP_SERVER_URL="ldap://127.0.0.1"

# LDAP connection test
echo -e "\nConnecting LDAP at $LDAP_SERVER_URL ..."

[[ ${WITH_LDAP_BIND} = "yes" ]] && LDAP_COMMAND_BEGIN="ldapsearch -LLL -H ${LDAP_SERVER_URL} -D uid=${LDAPADMIN_UID},${DN_USER_BRANCH},${DNBASE} -w ${LDAPADMIN_PASS}"
[[ ${WITH_LDAP_BIND} = "no" ]] && LDAP_COMMAND_BEGIN="ldapsearch -LLL -H ${LDAP_SERVER_URL} -x"

${LDAP_COMMAND_BEGIN} -b ${DN_USER_BRANCH},${DNBASE} > /dev/null 2>&1
if [ $? -ne 0 ]; then 
	error 2 "Error connecting to LDAP server.\nPlease verify your LDAP_SERVER_URL and, if needed to bind LDAP, user and pass."
else
	echo "OK!"
fi

# Test if user list is not empty
if [[ ${LDAPGROUP_OBJECTCLASS} = "groupOfNames" ]]; then
	if [[ -z $(${LDAP_COMMAND_BEGIN} -b ${LDAPGROUP},${DNBASE} member | grep member: | awk '{print $2}' | awk -F',' '{print $1}') ]]; then 
		error 3 "User list on LDAP group is empty!"
	else
		${LDAP_COMMAND_BEGIN} -b ${LDAPGROUP},${DNBASE} member | grep member: | awk '{print $2}' | awk -F',' '{print $1}' >> $LIST_USERS
	fi
elif [[ ${LDAPGROUP_OBJECTCLASS} = "posixGroup" ]]; then
	if [[ -z $(${LDAP_COMMAND_BEGIN} -b ${LDAPGROUP},${DNBASE} memberUid | grep memberUid: | awk '{print $2}' | sed -e 's/^./uid=&/g') ]]; then 
		error 3 "User list on LDAP group is empty!"
	else
		${LDAP_COMMAND_BEGIN} -b ${LDAPGROUP},${DNBASE} memberUid | grep memberUid: | awk '{print $2}' | sed -e 's/^./uid=&/g' >> $LIST_USERS
	fi
elif [[ ${LDAPGROUP_OBJECTCLASS} = "allusers" ]]; then
	if [[ -z $(${LDAP_COMMAND_BEGIN} -b ${DN_USER_BRANCH},${DNBASE} uid | grep uid: | awk '{print $2}' | sed -e 's/^./uid=&/g') ]]; then 
		error 3 "User list on LDAP ${DN_USER_BRANCH},${DNBASE} is empty"
	else
		${LDAP_COMMAND_BEGIN} -b ${DN_USER_BRANCH},${DNBASE} uid | grep uid: | awk '{print $2}' | sed -e 's/^./uid=&/g' >> $LIST_USERS
	fi
fi

[[ ! -d ${VIRTUAL_MAP_FILE} ]] && mkdir -p $(dirname ${VIRTUAL_MAP_FILE})

# Processing each user
echo -e ""
for USER in $(sort -d -f -b ${LIST_USERS})
do
	PRINCIPAL_EMAIL=""
    echo "- Processing user: $USER"
    EMAILS=$(mktemp /tmp/ldap2postfixmap_emails.XXXXX)
    OTHER_EMAILS=$(mktemp /tmp/ldap2postfixmap_secondry_emails.XXXXX)
    ${LDAP_COMMAND_BEGIN} -b ${DN_USER_BRANCH},${DNBASE} $USER mail | grep mail: | awk '{print $2}' | grep '.' | sed '/^$/d' | awk '!x[$0]++' >> $EMAILS
    LINES_NUMBER=$(cat ${EMAILS} | grep "." | wc -l) 
    echo -e "\tNumber of lines/emails: ${LINES_NUMBER}"
    if [[ ${LINES_NUMBER} -lt "2" ]]; then
    	echo -e "\t-> This user doesn't have enough email addresses registered in LDAP. Skip this user."
	elif [[ ${LINES_NUMBER} -gt "1" ]]; then
    	cat ${EMAILS} | grep ${VIRTUAL_DOMAIN_RELAYED} > /dev/null 2>&1
		if [ $? -ne 0 ]; then
    		echo -e "\t-> No email containing the virtual domain defined in LDAP. Skip this user."		
    	else
    		cat ${EMAILS} | grep -v ${VIRTUAL_DOMAIN_RELAYED} >> ${OTHER_EMAILS}
    		if [[ ${MAIN_DOMAIN_DEFINED} = "no" ]]; then
    			PRINCIPAL_EMAIL=$(cat ${OTHER_EMAILS} | head -n 1)
    		else
    			if [[ -z $(cat ${OTHER_EMAILS} | grep ${MAIN_DOMAIN}) ]]; then
    				PRINCIPAL_EMAIL=$(cat ${OTHER_EMAILS} | head -n 1)
    			else
    				PRINCIPAL_EMAIL=$(cat ${OTHER_EMAILS} | grep ${MAIN_DOMAIN} | head -n 1)
				fi    			
    		fi
    		if [[ -z ${PRINCIPAL_EMAIL} ]]; then
    			echo -e "\t-> No email destination found not containing the virtual domain. Skip this user."
    		else
    			# Add test to avoid duplicate emails in postfix map table
    			for VIRTUAL_EMAIL_ADDRESS in $(cat ${EMAILS} | grep ${VIRTUAL_DOMAIN_RELAYED})
	    		do
					cat ${VIRTUAL_MAP_FILE_NEW} | grep ${VIRTUAL_EMAIL_ADDRESS} > /dev/null 2>&1
					if [ $? -ne 0 ]; then
		    			echo "# User ${USER},${DN_USER_BRANCH},${DNBASE}" >> ${VIRTUAL_MAP_FILE_NEW} 				
		    			echo "${VIRTUAL_EMAIL_ADDRESS} ${PRINCIPAL_EMAIL}" >> ${VIRTUAL_MAP_FILE_NEW}
		    			echo -e "\t${VIRTUAL_EMAIL_ADDRESS} > ${PRINCIPAL_EMAIL}" 
		    		else
		    			DUPLICATED_EMAILS=1
		    			echo "${VIRTUAL_EMAIL_ADDRESS}" >> ${LIST_DUPLICATED_EMAILS}
		    			echo "# User ${USER},${DN_USER_BRANCH},${DNBASE}" >> ${VIRTUAL_MAP_FILE_NEW}
		    			echo "# ... this email ${VIRTUAL_EMAIL_ADDRESS} is already used in postfix map." >> ${VIRTUAL_MAP_FILE_NEW}
		    			echo "# ... in order to avoid postmap crashes, we skip this user." >> ${VIRTUAL_MAP_FILE_NEW}
		    			echo -e "\t!!! ${VIRTUAL_EMAIL_ADDRESS} is already used in postfix map !!!" 
		    		fi
		    	done
    		fi
    	fi
    fi
done

[[ ${DUPLICATED_EMAILS} -eq 1 ]] && DUPLICATED_EMAILS_INLINE=$(cat ${DUPLICATED_EMAILS} | sort -d -f -b | perl -p -e 's/\n/ /g')

if [[ -z $(cat ${VIRTUAL_MAP_FILE_NEW}) ]]; then
	echo -e "\n-> Nothing to import in ${VIRTUAL_MAP_FILE}"
else
	[[ -f ${VIRTUAL_MAP_FILE} ]] && mv ${VIRTUAL_MAP_FILE} ${VIRTUAL_MAP_FILE}.old
	echo "# Postmap file generated by ${SCRIPT_DIR}/${SCRIPT_NAME}" > ${VIRTUAL_MAP_FILE}
	echo "# ${VERSION}" >> ${VIRTUAL_MAP_FILE}
	echo "# `date`" >> ${VIRTUAL_MAP_FILE}
	echo "" >> ${VIRTUAL_MAP_FILE}
	cat ${VIRTUAL_MAP_FILE_NEW} >> ${VIRTUAL_MAP_FILE}
	${POSTMAP_COMMAND} ${VIRTUAL_MAP_FILE}
	if [ $? -ne 0 ]; then 
		ERROR_MESSAGE=$(echo ${?})
		error 4 "Error while running command: ${POSTMAP_COMMAND} ${VIRTUAL_MAP_FILE}.\n${ERROR_MESSAGE}."
	else
		echo -e "\n-> Postmap OK"
	fi
	[[ ${DUPLICATED_EMAILS} -eq 1 ]] && error 5 "Problem with LDAP email entries.\nA virtual email address can only be used one time in a postfix virtual map.\nHave a look to these emails: $DUPLICATED_EMAILS_INLINE !"
fi

alldone 0
