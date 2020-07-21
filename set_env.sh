##### Change history:
# 2020-02-06  Added "ulimit" changes to update the no. of files open limit
# 2020-02-06  Added auto-shutdown cron job
# 2020-03-16  Added more comments and re-ordered sections for handover
#########################


#### 1. ULIMIT Code - Change no. of files limit to 60K
file_limit=`ulimit -Sn | awk ' { print $NF } '`
if [[ ${file_limit} -lt 10000 ]]
then
echo -e "WARNING: Resetting the no. of files open limit from <${file_limit}> to <60240> and rebooting the box...\n"
sudo bash -c 'echo """
ec2-user         soft    nofile          60240
ec2-user         hard    nofile          60240
""" >> /etc/security/limits.conf'
sudo reboot
else
echo -e "PROPER ULIMIT <${file_limit}>: No reboot needed\n"
fi

#### 2. Add RAR/UNRAR to bin directory
sudo cp -v /home/ec2-user/SageMaker/utils/rar/rar /home/ec2-user/SageMaker/utils/rar/unrar /usr/local/bin/

#### 3. Additional utilities
sudo yum -y install htop tree

#### 4. Add conda to your bashrc
echo ". /home/ec2-user/anaconda3/etc/profile.d/conda.sh" >> ~/.bashrc

#### 5. Env default to bashrc
spark_v="2.4.0"
hadoop_v="3.1.1"
echo """export SPARK_VERSION="${spark_v}"
export HADOOP_VERSION="${hadoop_v}"
export PATH="$PATH:/home/ec2-user/SageMaker/spark/spark-${spark_v}-bin-without-hadoop/bin"
export JAVA_HOME=/usr/lib/jvm/java-openjdk/jre/
export SPARK_HOME=/home/ec2-user/SageMaker/spark/spark-${spark_v}-bin-without-hadoop
export SPARK_DIST_CLASSPATH=/home/ec2-user/SageMaker/spark/hadoop-${hadoop_v}/etc/hadoop:/home/ec2-user/SageMaker/spark/hadoop-${hadoop_v}/share/hadoop/common/lib/*:/home/ec2-user/SageMaker/spark/hadoop-${hadoop_v}/share/hadoop/common/*:/home/ec2-user/SageMaker/spark/hadoop-${hadoop_v}/share/hadoop/hdfs:/home/ec2-user/SageMaker/spark/hadoop-${hadoop_v}/share/hadoop/hdfs/lib/*:/home/ec2-user/SageMaker/spark/hadoop-${hadoop_v}/share/hadoop/hdfs/*:/home/ec2-user/SageMaker/spark/hadoop-${hadoop_v}/share/hadoop/mapreduce/lib/*:/home/ec2-user/SageMaker/spark/hadoop-${hadoop_v}/share/hadoop/mapreduce/*:/home/ec2-user/SageMaker/spark/hadoop-${hadoop_v}/share/hadoop/yarn:/home/ec2-user/SageMaker/spark/hadoop-${hadoop_v}/share/hadoop/yarn/lib/*:/opt/spark/hadoop-${hadoop_v}/share/hadoop/yarn/*
""" >> /home/ec2-user/.bashrc
source /home/ec2-user/.bashrc

#### 6. AIDA SPARK - Kernel registrations
mkdir -p /home/ec2-user/.local/share/jupyter/kernels/aida_spark
cp /home/ec2-user/SageMaker/SM_scripts/kernel.json /home/ec2-user/.local/share/jupyter/kernels/aida_spark/kernel.json 
# Add symlink to aida_spark to conda env path
ln -sf /home/ec2-user/SageMaker/venv/aida_spark/ /home/ec2-user/anaconda3/envs/aida_spark


#### 7. Auto-Shutdown Code - Schedule shutdown when SM is idle
IDLE_TIME=5400
check_shutdown=`crontab -l | grep "autostop.py"`
if [[ ${check_shutdown} == "" ]]
then
        echo -e "Adding Auto Shutdown in the CRON with idle time of <${IDLE_TIME}> seconds...\n"
	(crontab -l 2>/dev/null; echo "*/15 0-6 * * * /usr/bin/python /home/ec2-user/SageMaker/SM_scripts/autostop.py --time $IDLE_TIME --ignore-connections >> /home/ec2-user/SageMaker/SM_scripts/log_autostop.log 2>&1 ") | crontab -
        (crontab -l 2>/dev/null; echo "*/15 21-23 * * * /usr/bin/python /home/ec2-user/SageMaker/SM_scripts/autostop.py --time $IDLE_TIME --ignore-connections >> /home/ec2-user/SageMaker/SM_scripts/log_autostop.log 2>&1 ") | crontab -
else
        echo -e "Auto Shutdown already in CRON...\n"
fi


####### OTHER setup - specific to development cycle #########
#### Pipeline Scheduling code
check_pipeline_scheduling=`crontab -l | grep "daily_run.sh"`
if [[ ${check_pipeline_scheduling} == "" ]]
then
        echo -e "Adding pipeline scheduling to the CRON\n"
	(crontab -l 2>/dev/null; echo "0 20 * * 1-5 bash /home/ec2-user/SageMaker/project_repo/daily_run.sh >> /home/ec2-user/SageMaker/SM_scripts/log_pipeline_run.log 2>&1 ") | crontab -
else
        echo -e "Pipeline Scheduling already in CRON...\n"
fi


### Kedro
mkdir -p /home/ec2-user/.ipython/profile_default/startup
cp /home/ec2-user/SageMaker/SM_scripts/00-kedro-init.py /home/ec2-user/.ipython/profile_default/startup/00-kedro-init.py

#### GitHub SSH key moved to home directory
cp /home/ec2-user/SageMaker/github/.ssh/id_rsa.pub /home/ec2-user/.ssh/id_rsa.pub
cp /home/ec2-user/SageMaker/github/.ssh/id_rsa /home/ec2-user/.ssh/id_rsa


### Clean tmp directory
rm -rf  /home/ec2-user/SageMaker/tmp/*
