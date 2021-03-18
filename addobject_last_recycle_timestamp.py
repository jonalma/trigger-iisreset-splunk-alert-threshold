import json
import sys
  
  
# function to add to JSON 
def add_new_object(server, new_recycle_time, data_filename):
    with open(data_filename, 'r') as file: 
        json_data = json.load(file) 
      
        # python object to be appended 
        new_object = {"host": server, 
             "last_recycle_timestamp": new_recycle_time 
            }  
  
        # appending new object to json_data array  
        json_data.append(new_object)
    
    with open(data_filename,'w') as file:
        json.dump(json_data, file, indent=2)
      
def main():
    server = sys.argv[1] # prints server name
    new_recycle_time = sys.argv[2] #the new recycle time (aka current timestamp)
    data_filename = sys.argv[3] # prints the JSON file to edit
    #cc_count = sys.argv[4] #get count of concurrent connections

    # call add_new_object function
    add_new_object(server, new_recycle_time, data_filename)

main()
