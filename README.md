# Use-case/Requirement

    1. You have multiple EC2 instances and all these EC2 instances have stand-alone application running which is 'AWS Kinesis Agent'. 
    
    2. Now, these Kinesis agents publishes custom CloudWatch metrics with a single namespace of 'AWSKinesisAgent' [1]

    3. Due to this all the metric data points from multiple Kinesis agents get combined under single namespace.

    4. Now, if for some reason, out of these multiple Kinesis Agents, a Kinesis Agent running on an EC2 instance goes down; then it is then hard to determine exactly which Kinesis Agent went down?

    5. In this case, below is the solution or a way that you can use to monitor health of multiple Kinesis Agents running on several EC2 instances.

# Solution

    1. Every EC2 instance, which has 'AWS Kinesis Agent' running, will have 'Amazon Cloudwatch Agent' installed using 'AWS Systems Manager Run Command' which is offered at no additional cost [2].

    2. This CW Agent, pushes custom metrics data to Amazon CloudWatch. This may cost you additional amount. However, for more on details on that, please check 'AWS Cloudwatch Pricing' page [3].
 
    3. The 'procstat plugin' collects, 'process metrics'. As long as the process (in our use-case the process is aws-kinesis-agent) is running inside the instance, the plugin will continuously monitor the specified metrics [4]

    4. Set-up CloudWatch alarm for all the custom metrics and set its missing data policy to Treat missing data as bad (breaching threshold) to trigger an alarm condition.

    5. When the process is stopped or crashed on the instance, the alarm goes into the state 'In alarm'. As an additional step you can have 'SNS email notification' enabled under alarm actions [5] (but in this arctile I have skipped that part)

    6. Later, instead of automatically restarting the Kinesis agent in this case, it is better if you see why it has failed, using troubleshooting steps and then restart by yourself the Kinesis Agent on that EC2 instance.


# Prerequisites

1. Have the AWS Systems Manager Agent (SSM Agent) installed and running.
2. Have connectivity with Systems Manager endpoints using the SSM Agent.
3. Have the correct AWS Identity and Access Management (IAM) role attached.
4. Have connectivity to the instance metadata service.

* IMP Note: For more detailed information on how to set-up and check the above prerequisites, please check AWS Premium Support Article: https://aws.amazon.com/premiumsupport/knowledge-center/systems-manager-ec2-instance-not-appear/

* As an additional, important point to note, please make sure you are following below steps while checking 3rd prerequisites from above:

  1. By default, AWS Systems Manager doesn't have permission to perform actions on your instances. Grant access by using an AWS Identity and Access Management (IAM) instance profile. An instance profile is a container that passes IAM role information to an Amazon Elastic Compute Cloud (Amazon EC2) instance at launch [6].

  2. So, the IAM role that you attached to your EC2 instances where Kinesis Agent is running, should have following managed policies attached [6][7]:


		=> Policy: AmazonSSMManagedInstanceCore

		    - Required permissions.

		    - This AWS managed policy allows an instance to use Systems Manager service core functionality.

		=> Policy: CloudWatchAgentServerPolicy

		    - Required only if you plan to install and run the CloudWatch agent on your instances to read metric and log data on an instance and write it to Amazon CloudWatch. These help you monitor, analyze, and quickly respond to issues or changes to your AWS resources. 

		=> Policy: AmazonSSMPatchAssociation

			- Provide access to child instances for patch association operation. 

# Once you are done with above prerequisites set-up, please follow below steps to achieve the solution:-

## Part A:- Installing CloudWatch Agent on all EC2 instances:-

  1. Open 'AWS Systems Manager' AWS console and from the left navigation pane under 'Node Management' section , choose 'Run Command'.

  2. On this 'Commands' page, click on 'Run command' button to add a command.

  3. Then on the 'Search Bar' type 'AWS-ConfigureAWSPackage' and press 'Enter' to look for this document and select it once it appears. * Note:- See screen-shot named 'Third_Step.png' for reference.

  4. Scroll little down, and under 'Command parameters' section, for field 'Name', type 'AmazonCloudWatchAgent'.  * Note:- See screen-shot named 'Fourth_Step.png' for reference.

  5. Now, scroll just a little, and under 'Targets' section -> Select 'Choose instances manually' -> After that you shall see list of all the EC2 instances below -> Out of those choose the ones (checked the boxes) on which 'AWS Kinesis Agent' application is running. * Note:- See screen-shot named 'Fifth_Step.png' for reference.

  6. You can export the command output to an S3 bucket, in Output options, select the Write command output to an S3 bucket box and enter an S3 destination bucket. However, this will cost you more hence I will leave this decision to you. But, I had disabled this option. * Note:- See screen-shot named 'Sixth_Step.png' for reference.

  7. Leave all the other parameters at their default values.

  8. Go at the bottom of the page, and click 'Run' button. You can watch the command’s progress from the Commands. * Note:- See screen-shot named 'Eighth_Step.png' for reference.

  9. After the status transitions to 'Success', it means 'AWS Cloudwatch Agent' got successfully installed on all the EC2 instances that you had selected in 'Fifth_Step' above. Moving ahead, you can configure the CloudWatch agent. * Note:- See screen-shot named 'Ninth_Step.png' for reference.

## Part B:- Configuring CloudWatch Agent on all EC2 instances:-

* Note:- You will have to follow the below step for each and every EC2 instance, where Kinesis Agent is running.

  10. Open Amazon EC2 console, choose your EC2 instance, and then choose Connect.

  11. Once you successfully SSH or make connection to your EC2 instance, you will have to create a CloudWatch agent configuration file (I used nano editor below)

    . Command: sudo nano /opt/aws/amazon-cloudwatch-agent/bin/config.json

  12. Inside the above file, put below content:

    ```
    
          {
                "agent": {
                        "run_as_user": "cwagent"
                },
                "metrics": {
                        "metrics_collected": {
                          "procstat": [
                          {
                              "pid_file": "/var/run/aws-kinesis-agent.pid",
                              "measurement": [
                                  "memory_rss"
                              ]
                          }
                        ]
                        }
                }
        }

    ```
    13. This configuration enables the 'procstat plugin' and tells it to monitor the 'aws-kinesis-agent' process identified by the 'aws-kinesis-agent.pid' file. The plugin will monitor the 'memory_rss' metric of this process and send information to Amazon CloudWatch. 

  * Note:- Metric memory_rss:- Tells the amount of real memory (resident set) that the process is using (Unit: Bytes) (Ref:- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-procstat-process-metrics.html)

  14. Now, use the following command to start the CloudWatch agent with its new configuration:

    . Command: sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

    * Note:- This command will configure the 'amazon-cloudwatch-agent' service on this machine where you can start, stop, and restart with 'systemctl' commands.

    * Note:- To check if cloudwatch agent is running, run following command on EC2 instance (Ref:- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/troubleshooting-CloudWatch-Agent.html ):

    . Command: sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status

    . Expected Output:
    
    ```
      {
            "status": "running",
            "starttime": "2021-08-07T15:41:54+0000",
            "configstatus": "configured",
            "cwoc_status": "stopped",
            "cwoc_starttime": "",
            "cwoc_configstatus": "not configured",
            "version": "1.247349.0b251399"
          }
    
    ```
## Part C:- Create a CloudWatch alarm:-

  15. Open 'AWS Cloudwatch' console, on left navigation bar under 'Metrics' section choose 'All metrics' option -> This will lead to a page where you shall see a newly created 'Custom Namespace' named as 'CWAgent'

  16. Click on that 'CWAgent' namespace -> Click on 'host, pidfile, process_name' on next page 

  17. Now, here you will see all your EC2 instances which have Kineis Agent installed and select one of those for metric name 'procstat_memory_rss'. => Note:- See screen-shot named 'Seventeenth_Step.png' for reference.

  18. Under Actions, choose the bell icon to open the Create alarm page.

  19. In Metric, for Period, choose 1 minute. Leave the other parameters at their defaults. => Note:- See screen-shot named 'Nineteenth_Step.png' for reference.

  20. Under section 'Conditions', fill the fields as shown in screen-shot 'Twentieth_Step.png'.

  21. These settings tell CloudWatch to go into the In alarm state if the 'procstat_memory_rss' metric value goes lower or equal to 0, or missing data is detected. Important thing to note, that a memory consumption metric will never go below or equal to zero for a running process, so this alarm configuration is practically tracking a missing data situation. Whenever the 'aws-kinesis-agent' process is 'stopped or crashed', the operating system will delete its pid file. The CloudWatch agent will detect the deletion and will not emit any metric data as long as the file is missing. This will cause the CloudWatch alarm to go into the In alarm state.

  22. After this, Choose Next -> I did not configure any actions for alarm -> Choose Next -> Enter a Alarm Name and Alarm Description -> Choose Next and this will create CW Alarm for selected EC2 instance successfully. 

  23. For reference, see the screenshot 'Twenty-Second_Step.png' -> Here I have two custom alarms configured for two EC2 instances who have Kinesis Agent running.

## Part D:- Testing and Troubleshooting:-


  24. For example: I stopped the Kinesis Agent running on one of my EC2 instance using following command OR the Kinesis Agent process stopped running by itself for some reason:
  
    ```
    sudo systemctl stop aws-kinesis-agent

    (To check if it has stopped; command: sudo systemctl status aws-kinesis-agent)
    ```

  25. I will see my alarm go up with state 'In alarm' as shown in scren-shot 'Twenty-Fifth_Step.png'. If you click on the alarm name which was showing state 'In alarm', under 'Details' section from 'host' you can identify which is the EC2 instance on which Kinesis Agent process stopped running . Another, easy way of identifying the concerned EC2 instance, is give your alarm name related to name of EC2 instance.

  26. As soon as you see an alarm on particular EC2 instance, log in to that EC2 instance and check the Kinesis Agent logs by running below command and this may help you in finding the reason what has causing Kinesis Agent running on that EC2 instance go down.  
  
  ```
    Command: cat  /var/log/aws-kinesis-agent/aws-kinesis-agent.log
  ```

  27. After this, if Kineis Agent did not restart automatically, you can run the below command to start the Kineis Agent again:
  
    ```
    sudo systemctl start aws-kinesis-agent
    ```
## Part E:- Conclusion:-

* To conclude, using Amazon CloudWatch agent on multiple EC2 instances we publish custom metrics under namespace 'CWAgent'. This provides a reliable way to collect 'AWS Kinesis Agent' process liveness information. Further, you will get notified using CW alarm that we created if ''AWS Kinesis Agent' processe and service goes down unexpectedly which will allow you to take remedial actions for continued business operations.

## References

[1] https://docs.aws.amazon.com/streams/latest/dev/agent-health.html

[2] https://docs.aws.amazon.com/systems-manager/latest/userguide/execute-remote-commands.html

[3] https://aws.amazon.com/cloudwatch/pricing/

[4] https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-procstat-process-metrics.html

[5] https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/US_SetupSNS.html

[6] https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-profile.html

[7] https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-launch-managed-instance.html
