#!/bin/bash

function erase-diskpartition-table(){
  echo -e "g
           w" | fdisk "${device}"
}

function format-partition(){
  [ "${2}" = "swap"  ] && {
    echo y | mkswap  "${device}""${1}"
    return ${?}
  }
  
  [ "${2}" = "btrfs" ] && {
    mkfs.btrfs -f "${device}""${1}"
    return ${?}
  }
  
  echo y | mkfs."${2}" "${device}""${1}"
  return ${?}
}

function delete-partition() {
  echo "d
        ${1}" | fdisk "${device}"
}

function create-partition(){
  partition_size=$(echo "(${2}*${disk_size_sectors})/${disk_size_gigabytes}")
  
  echo "n
        ${1}
        
        ${partition_size}
        y
        w" | fdisk "${device}"
}

device=$(echo "${1}" | cut -c 10-); shift
[ ! -f "${device}" ] && {
  echo "Fatal error: '${device}' not found"
}

disk_size_bytes=$(echo "p" | fdisk "${device}" | grep -o ",.*bytes" | cut -d' ' -f2)
disk_size_gigabytes=$(echo "${disk_size_bytes}"/1024/1024/1024|bc)
disk_size_sectors=$(echo "p" | fdisk "${device}" | grep -o "bytes.*sectors$" | cut -d' ' -f2)

[ "${1}" = "--erase-partition-table" ] && {
  erase-diskpartition-table
  shift
  partprobe "${device}"
}

for arg in "${@}"; do
  echo "${arg}" | grep -q ^"--install-partition=" && {
    target_partition=$(echo "${arg}" | cut -c 21-)
    shift
  }
  echo "${arg}" grep -q ^"--delete-partition=" && {
    number=$(echo "${arg}" | cut -c 20-)
    
    format-partition "${number}"
  }
  echo "${arg}" | grep -q ^"--create-partition=" && {
    params=$(echo "${arg}" | cut -c 20-)
    number=$(echo "${params}" | cut -d: -f1)
    size=$(echo "${params}" | cut -d: -f2)
    format=$(echo "${params}" | cut -d: -f3)
    
    create-partition "${number}" "${size}" "${format}"
  }
  echo "${arg}" grep -q ^"--format-partition=" && {
    params=$(echo "${arg}" | cut -c 20-)
    number=$(echo "${params}" | cut -d: -f1)
    format=$(echo "${params}" | cut -d: -f2)
    
    format-partition "${number}" "${format}"
  }
done


[ -f "${target_partition}" ] && {
  mkdir -p /target
  mount -o rw "${target_partition}"  /target
}
