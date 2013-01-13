# Pattern-based Deployer

This is an automated pattern-based deployer that deploy user-provided applications to the cloud.
Our goals is to make the deployment of application painless.

We let user to describe their applications as intuitive *pattern* and we deploy their applications accroding to the their *pattern*.

## What is pattern

We use the word *pattern* to describe: what software(s) need to install, what application component(s) need to deploy, what application configuration(s) need to tune, etc.
The application *pattern* should be cloud-independent, platform-indepedent, flexiable, easy-to-read and easy-to-modify.

We used XML document to describe *pattern*(But we don't means only XML can describe *pattern*). An example pattern is as following

    <topology id="simple_topology">
      <instance_templates>
        <template id="ec2_instance">
          <key_pair_id>hongbin-deployer-test1</key_pair_id>
          <ssh_user>ubuntu</ssh_user>
          <cloud>EC2</cloud>
          <image_id>ami-cdc072a4</image_id>
          <security_groups>quicklaunch-1</security_groups>
        </template>
        <template id="ec2_micro_instance">
          <extend template="ec2_instance"/>
          <instance_type>t1.micro</instance_type>
        </template>
      </instance_templates>
      <node id="web_host">
        <use_template name="ec2_micro_instance"/>
        <service name="web_server">
          <database node="web_host"/>
          <war_file>
            <file_name>myapp.war</file_name>
            <datasource>jdbc/SimpleDbOperations</datasource> 
          </war_file>
        </service>
        <service name="database_server">
          <script>mydb.sql</script>
        </service>
      </node>
    </topology>

This pattern describe a typical Java web application.
We said the application is a topology, and each cloud instance is node.
In brief, this pattern gives the following information.

* A EC2 micro instance need to be launched 
* A web server and a database server need to install in the instance.
* The web server will host a war file(myapp.war) which is provided by user.
* An user-provided SQL script(mydb.sql) will be executed to setup the database(s)/table(s) in the database server.

Here is a more complicated sample pattern

    <topology id="standard_topology">
      <instance_templates>
        <template id="ec2_instance">
          <key_pair_id>hongbin-deployer-test1</key_pair_id>
          <ssh_user>ubuntu</ssh_user>
          <cloud>EC2</cloud>
          <image_id>ami-cdc072a4</image_id>
          <security_groups>quicklaunch-1</security_groups>
        </template>
        <template id="ec2_micro_instance">
          <extend template="ec2_instance"/>
          <instance_type>t1.micro</instance_type>
        </template>
      </instance_templates>
      <container id="web_host_container" num_of_copies="2">
        <node id="web_host">
          <use_template name="ec2_micro_instance"/>
          <service name="web_server">
            <database node="data_host"/>
            <war_file> 
              <file_name>myapp.war</file_name>
              <datasource>jdbc/SimpleDbOperations</datasource> 
            </war_file>
          </service>
        </node>
      </container>
      <node id="data_host">
        <use_template name="ec2_micro_instance"/>
        <service name="database_server">
          <script>mydb.sql</script>
        </service>
      </node>
      <node id="web_balancer">
        <use_template name="ec2_micro_instance"/>
        <service name="web_balancer">
          <member node="web_host"/>
        </service>
      </node>
    </topology>

This pattern describe a typical application deployment with high availability.
This pattern gives us the following information

* User want to launch totally 4 instances in EC2. 
* One for database server
* Two for web server 
* One for load balancer.

The logic behind the pattern is that if one web server is failed, the load balancer will route all request to another web server.

## Why pattern

Currently, deploying applications to the cloud is normally done by writing a dedicated custom script(s) and running those script(s) to deploy.
There are several disadvantages of this approach.

* ####Cloud dependent

If applications need to be deployed to different cloud, the deployment script(s) need to be re-written which incurs maintainence cost and it is error-prone.

* ####Application specific

The deploying script(s) will only work for specific application and hard to be re-used.

* ####Complicated

For deploying a large system, the deploying script(s) is likely to be complicated and error-prone.

* ####Platform dependent

The custom script(s) is likely to only work on specific platform and hard to port to another platform.

## Our passion

We were working on research & development of application on the cloud and we experienced the difficulties and complication application deployment.
Therefore, we developed this tool and premote the pattern-based approach.
We argue that pattern-based approach can reduce the complexity of application deployment, specifically on cloud.

## How to Deploy

1. Users need to sign in or sign up first.

1. Go to the API Doc. It contains the API Documentation of the deployer along with an GUI to use the deployer.
![api_doc](/assets/get_started/api_doc.png)

1. Users need to hand their credentials to the deployer. The credential is used to authenticate users to the cloud.
![submit_cred1](/assets/get_started/submit_cred1.png)
![submit_cred2](/assets/get_started/submit_cred2.png)

2. Users need to upload their identity file. Users need to indicate the keypair and cloud this identity file for.
![id_file1](/assets/get_started/id_file1.png)
![id_file2](/assets/get_started/id_file2.png)

3. Users need to upload their war file which contains the application to deploy.
![war](/assets/get_started/war.png)

4. Users need to upload their SQL script that is used to setup the database.
![sql](/assets/get_started/sql.png)

5. This is the key part. Users need to upload their *pattern*.
![pattern1](/assets/get_started/pattern1.png)
![pattern2](/assets/get_started/pattern2.png)

6. Deploy the pattern.
![deploy1](/assets/get_started/deploy1.png)
![deploy2](/assets/get_started/deploy2.png)

Then you should see the instance(s) are launched in the cloud.

## Run-time management

Work in progress

## Undeploy

If you finished using your application, you'd better to undeploy it from the cloud.

![undeploy](/assets/get_started/undeploy.png)

## Can I programmatically deploy/undeploy?

Of course. As you may notice, what the deployer provides is an Restful Web Service, so you can just write a Restful client in your favor language to consume the service.

For authentication, if you don't want to deal with session data in cookie, you can use [HTTP Basic](http://en.wikipedia.org/wiki/Basic_access_authentication), which is a widely support anthentication method.

## Administration

We provide an admin panel with the deployer. If you are admin, you can see the panel here.
![admin1](/assets/get_started/admin1.png)

The first registered user becomes an admin automatically. 
Admins can access all resources while normal users can access the resources they own.
Admin can premote other user as admin as well. The procedure is as following.
![admin2](/assets/get_started/admin2.png)
![admin3](/assets/get_started/admin3.png)

The role is originally of "user". Change it to "admin" and save.
![admin4](/assets/get_started/admin4.png)

## Further detail.

As you already saw, we provides an API doc along with the deployer. You can find more detail information there.