# Monitoring Splunk Indexes with Zabbix

This project integrates Splunk index monitoring into Zabbix using a custom script and Low-Level Discovery (LLD). The goal is to monitor the size of individual indexes (directories) within the Splunk storage tiers: HOT, COLD, and FROZEN. The solution provides real-time insights into the storage usage of each index, enabling proactive management and preventing potential storage overflows or performance issues.

-----------------------------------------------------------------------------------------------------------------------------------------------------------------
# Objectives:

  *Automated Index Discovery:
        Automatically detect all subdirectories (indexes) in the specified Splunk storage paths (/HOT, /COLD, /FROZEN) using a discovery mechanism in Zabbix.

  *Index Size Monitoring:
        Monitor the size of each discovered index directory in real-time.
        Report size in bytes (or kilobytes) for accurate tracking.

  *Threshold-Based Alerts:
        Configure Zabbix triggers to generate alerts if the size of any index exceeds a predefined threshold (e.g., 1 GB).
        This ensures that administrators are notified promptly to address storage issues.

  *Extensibility:
        The solution is designed to be easily extended to other directories or storage tiers by updating configuration parameters in Zabbix.
  
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------

 # Key Features:

  *Custom Bash Script:
        A lightweight script that performs two actions:
            Discover: Lists all subdirectories in a specified path.
            Size Calculation: Calculates the size of a given directory in bytes.

  *Zabbix Integration:
        The script is integrated into Zabbix using UserParameter directives in the Zabbix Agent configuration.
        Low-Level Discovery (LLD) rules are used to dynamically create monitoring items for each index.

  *Granular Monitoring:
        Separate discovery rules for /HOT, /COLD, and /FROZEN, allowing independent monitoring of each Splunk storage tier.

  *Custom Triggers:
        Alerts based on specific size thresholds for each index, ensuring that potential issues are flagged before they escalate.

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------

# Benefits:

  *Proactive Monitoring:
        Gain real-time visibility into Splunk index storage usage, reducing the risk of exceeding storage limits.

  *Automation:
        Eliminates the need for manual configuration by dynamically discovering and monitoring indexes.

   *Scalability:
        Supports monitoring of additional directories or storage tiers with minimal configuration changes.

  *Operational Efficiency:
        Helps administrators optimize storage allocation, plan capacity upgrades, and resolve issues quickly.

  ----------------------------------------------------------------------------------------------------------------------------------------------------------------

# Use Case:

Splunk stores its indexed data across three main storage tiers (/HOT, /COLD, /FROZEN), which can grow significantly depending on the workload. 
Without proper monitoring, indexes may grow beyond allocated storage, impacting performance or causing outages. This project addresses this challenge by providing 
a centralized and automated way to track index sizes, making it easier to manage storage resources effectively.

  ----------------------------------------------------------------------------------------------------------------------------------------------------------------


# Step 1: Create the Monitoring Script

  1-Create the directory for the script:
    
    mkdir -p /etc/zabbix/scripts

  2-Create and edit the script file:

    nano /etc/zabbix/scripts/monitor_dir_sizes.sh

  3-Paste the following script into the file:

      #!/bin/bash

      ACTION=$1
      BASE_PATH=$2

      if [[ "$ACTION" == "discover" ]]; then
      # Discover subdirectories in the given path
        find "$BASE_PATH" -mindepth 1 -maxdepth 1 -type d | awk -F/ '{print "{\"{#SUBDIR}\":\"" $NF "\"}"}' | jq -s '{data: .}'

      elif [[ "$ACTION" == "size" ]]; then
      # Calculate the size of the given subdirectory
        DIR="$BASE_PATH"
        if [ -d "$DIR" ]; then
        # Get size in kilobytes, suppress errors, and convert to bytes
          du -sk "$DIR" 2>/dev/null | awk '{print $1 * 1024}'
        else
        # If directory does not exist or is inaccessible, return 0
          echo "0"
        fi

    else
      echo "Invalid action"
      exit 1
    fi

  4-Make the script executable:
  
    chmod +x /etc/zabbix/scripts/monitor_dir_sizes.sh

  5-Install jq for JSON parsing:
  
    apt install -y jq

#  Step 2: Configure Zabbix Agent

  1-Edit the Zabbix agent configuration:

      nano /etc/zabbix/zabbix_agent2.conf
  
  2-Add the following lines for custom UserParameters:
  
    UserParameter=custom.dir.discovery[*],/etc/zabbix/scripts/monitor_dir_sizes.sh discover $1
    UserParameter=custom.dir.size[*],/etc/zabbix/scripts/monitor_dir_sizes.sh size $1

  3-Restart the Zabbix agent:
  
    systemctl restart zabbix-agent2

  4-Test the configuration to ensure it works:

    zabbix_agent2 -t custom.dir.discovery[/HOT]

#  Step 3: Prepare Splunk Directories
  1-Set proper permissions for the directories:

    chmod -R 755 /FROZEN
    chmod -R 755 /HOT
    chmod -R 755 /COLD

  2-Restart the Zabbix agent again:

    systemctl restart zabbix-agent2

# Step 4: Configure Low-Level Discovery (LLD) Template in Zabbix

  1-Create a Discovery Rule:
  
  Go to Data Collection → Templates → Create template (e.g. splunk_index_size) .
  Then Navigate to the Discovery section → Click Create discovery rule:
  
  For HOT:
  
  Name: Directory Discovery (/HOT)
  
  Key: custom.dir.discovery[/HOT]
  
  Type: Zabbix agent
  
  Update interval: 3600 (or 1 hour).
  
  Apply

  For COLD:
  
  Name: Directory Discovery (/COLD)
  
  Key: custom.dir.discovery[/COLD]
  
  Type: Zabbix agent
  
  Update interval: 3600 (or 1 hour).
  
  Apply

  For Frozen:
  
  Name: Directory Discovery (/FROZEN)
  
  Key: custom.dir.discovery[/FROZEN]
  
  Type: Zabbix agent
  
  Update interval: 3600 (or 1 hour).
  
  Apply

  2-Add Item Prototypes:

  Inside the discovery rule, create an item prototype:

  For HOT:
  
  Name: {#SUBDIR} in HOT
  
  Key: custom.dir.size[/HOT/{#SUBDIR}]
  
  Type: Zabbix agent
  
  Type of information: Numeric (unsigned)
  
  Units: B


  For COLD:
  
  Name: {#SUBDIR} in COLD
  
  Key: custom.dir.size[/COLD/{#SUBDIR}]
  
  Type: Zabbix agent
  
  Type of information: Numeric (unsigned)
  
  Units: B



  For FROZEN:

  Name: {#SUBDIR} in FROZEN
  
  Key: custom.dir.size[/FROZEN/{#SUBDIR}]
  
  Type: Zabbix agent
  
  Type of information: Numeric (unsigned)
  
  Units: B

  3-Add Trigger Prototypes:

  Create a trigger prototype to alert if the directory size exceeds a threshold:

  
  FOR HOT:
  
  Name: {#SUBDIR} size exceeds 500GB
  
  Expression:
            
    last(/splunk_index_size/custom.dir.size[/HOST/{#SUBDIR}])>500000000000


  FOR COLD:
  
  Name: {#SUBDIR} size exceeds 500GB
  
  Expression:
            
     last(/splunk_index_size/custom.dir.size[/COLD/{#SUBDIR}])>500000000000


  FOR FROZEN:
  
  Name: {#SUBDIR} size exceeds 500GB
  
  Expression:
            
     last(/splunk_index_size/custom.dir.size[/FROZEN/{#SUBDIR}])>500000000000




# Step 6: Verify and Test
  
  1-Check if Zabbix discovers the directories:

    zabbix_agent2 -t custom.dir.discovery[/HOT]
    zabbix_agent2 -t custom.dir.discovery[/COLD]
    zabbix_agent2 -t custom.dir.discovery[/FROZEN]


  2-Verify the size calculation:

    zabbix_agent2 -t custom.dir.size[/HOT/some_subdir]
