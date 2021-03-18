#!/usr/bin/python
import json
import sys 

def replace_value(server, new_recycle_time, data_filename):
    with open(data_filename, 'r') as file:
        json_data = json.load(file)
        for item in json_data:
            if item['host'] == server:
                item['last_recycle_timestamp'] = new_recycle_time

    with open(data_filename, 'w') as file:
        json.dump(json_data, file, indent=2)


def main():
    server = sys.argv[1] # prints server name
    #print(server)
    new_recycle_time = sys.argv[2] #the new recycle time (aka current timestamp)
    #print(new_recycle_time)
    data_filename = sys.argv[3] # prints the JSON file to edit
    #print(data_filename)
    
    # call read_json function
    replace_value(server, new_recycle_time, data_filename)

main()
