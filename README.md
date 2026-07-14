WHM Automation Script Execution Guide 
Instructions for Running the Script: 
Step 1: Configure the Hostname - 
➔ First, set or update the hostname on the Direct-Admin server. 
➔ Next, log in to the DNS host server and create the required DNS record for the 
hostname. Use the following naming convention: 
<client-name><last-IP-digit>.dnshostserver.in 
Example : Pinnacle80.dnshostserver.in. 
Step 2: Apply the License - 
➔ Apply the license to the server IP using GetLic or V2, depending on your licensing 
source. 
➔ Note: If an original license is required for the server, do not use GetLic or V2. Skip this 
step and apply the original license. 
Step 3: Download and Execute the WHM Automation Script -  
➔ Log in to the server where WHM will be installed. 
➔ Download the automation script from GitHub: 
➔ Using wget:  
https://raw.githubusercontent.com/kushal-hostnetindia/WHM-Automation-scr
ipt/main/auto.sh 
➔ Make the script executable :  chmod +x auto.sh 
➔ Run the script:: ./auto.sh 
Prepared By: Kushal Jangid                                                                               
Version: 1.0  
Step 4: Configure the WHM Automation Script -  
Once the script starts, carefully read the on-screen instructions. Press Enter to continue. 
Provide the required details when prompted: 
➔ Your Name – Enter your name. 
➔ Client Name – Enter the client's name 
➔ Hostname – The hostname must exactly match the DNS record created in Step 1 
using the following format: 
<client-name><last-IP-digit>.dnshostserver.in 
Example: Pinnacle80.dnshostserver.in 
➔ cPanel Version – Enter the required cPanel version (e.g., 11.126, 11.130, 11.132, 
11.134, 11.136, or release). Press Enter to install the latest available version. 
➔ License Source – Select the appropriate option: 
❖ 1 – V2 License 
❖ 2 – GetLic 
❖ 3 – Skip license installation 
➔ Node Exporter – Choose whether to install Node Exporter by entering Yes or No. 
➔ Congratulations! The automation script has started successfully. 
❖ Please wait 2–3 minutes until the script completes and returns to the terminal 
screen. Once the process is finished, you may safely exit the script. 
—————————————————————————————————————————— 
                                                       Troubleshooting - 
➔ Note: If the script fails because the screen package cannot be installed or you 
encounter a DNS resolution error, update the DNS resolver by running the following 
commands: 
❖ cat >> /etc/resolv.conf <<EOF  
❖ nameserver 8.8.8.8 
❖ nameserver 8.8.4.4  
❖ EOF  
➔ This issue usually occurs due to incorrect DNS configuration on the server. After 
updating the DNS settings, rerun the automation script.  
 
 
 
 
 
 
 
 
Prepared By: Kushal Jangid                                                                               Version: 1.0 
