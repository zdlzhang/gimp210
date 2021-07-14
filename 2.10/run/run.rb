#! /usr/bin/ruby

require 'optparse'

'''
Test method and samples are from phoronix. The gimp test consists of 4 parts:
    *batch-unsharp-mask
    *batch-resize-image
    *batch-rotate
    *batch-auto-levels
    *Script Owner: suzhang@amd.com
'''

options = {}
OptionParser.new do |opts|

opts.banner = "Usage: run.rb -t 1800"

    opts.on('-t', '--time 1800', 'time you want the job to run for') { |arg| options[:time] = arg }
	
end.parse!

runtime = options[:time].to_i

if runtime == 0
	runtime = 1800
end

puts "Starting journalctl to check kernel messages..."
#journal = IO.popen("journalctl -kf | tee kernelmessages.log")

bad_messages = Array.new 
#bad_messages << "[Hardware Error]" << "Machine check events logged" << "mce:" << "segfault" << "uop cache tag parity error" #known kernel messages for MCE


def get_rc()
	$rc = $?.exitstatus
	$pid = $?.pid
	puts "Task #{$task} with pid #{$pid} exited with return code #{$rc}"
	File.open("#{$workload_name}.log", "a"){|f| f.write("Task #{$task} with pid #{$pid} exited with return code #{$rc}\n")}
	if $rc != 0
			exit($rc)
	end
end

#this workload is taken/translated from old linux testmenu.sh
#trying to keep as much of it intact as possible, just want to run it through apex instead of shell script

$workload_name = "gimp"
workload_file = `ls *.bz2 *.xz`
puts "Workload file is #{workload_file}"
puts "Deleting old JPG files and extracting new test JPG."


$preTest = "
    rm -f *.JPG *.png && \
    tar -xjf pts-sample-photos-2.tar.bz2 && \
    tar -xf stock-photos-jpeg-2018-1.tar.xz "
puts "preTest is #$preTest"

puts "generate gimp batch"
generateGimpBatch = `./CreateBatch.sh`
puts generateGimpBatch  

#detect which distro we are on - /etc/os-release is part of systemd spec, i don't believe we officially support any non-systemd distro
os_release = `cat /etc/os-release`
distro = os_release.scan(/^NAME="(.+)"/).join("")
	
if distro == "Ubuntu"
	$task = "apt install gimp"
	puts "Installing gimp with package manager..."
	get = `apt install gimp -y 2>&1`
	get_rc()
	puts get

	$task = "Installing appmenu-gtk2-module appmenu-gtk3-module"
	puts "Installing appmenu-gtk2-module appmenu-gtk3-module with package manager"
	get = `apt install appmenu-gtk2-module appmenu-gtk3-module -y`
	puts get
	get_rc()

	$task = "Installing canberra-gtk-module"
	puts "Installing libcanberra-gtk-module with package manager"
	get = `apt install libcanberra-gtk-module -y`
	puts get
	get_rc()
elsif distro.include?("Red Hat Enterprise Linux")
	$task = "yum install gimp"
	puts "Installing gimp with package manager..."
	get = `yum install gimp -y 2>&1`
	puts get
	get_rc()
	#$task = "yum install libcanberra-gtk-module"
	#get = `yum install libcanberra-gtk-module -y 2>&1`
	#puts get
	#get_rc()
end


command = "
    #{$preTest} && gimp -i -b \"'(batch-unsharp-mask \"*.JPG\" 15.0 0.6 0)'\" -b '(gimp-quit 0)' && 
    #{$preTest} && gimp -i -b \"'(batch-resize-image \"*.JPG\" 600 400)'\" -b '(gimp-quit 0)' &&
    #{$preTest} && gimp -i -b \"'(batch-rotate \"*.JPG\")'\" -b '(gimp-quit 0)' &&
    #{$preTest} && gimp -i -b \"'(batch-auto-levels \"*.JPG\")'\" -b '(gimp-quit 0)' &&
    #{$preTest} && rm -f ~/.gimp-*/gimpswap.* | tee -a #{$workload_name}.log"
	
#run 30m by default
$task = "gimp batch mode"

start = Time.now
endTime = start + runtime
puts "gimp start time is #{start}"
puts "gimp planed end time is #{endTime}"
while Time.now < endTime
    system("#{command}")
    get_rc()
    puts Time.now
end

#clear test files
get = `rm -rf *.JPG *.png`
puts get

#parse result here

#kill_subprocess = `killall journalctl`
#
#kernel_messages = File.read('kernelmessages.log')
#
#if kernel_messages.length >=1
#	bad_messages.each {|err| #check log for list of errors and fail if they are there
#		if kernel_messages.include?("#{err}")
#			puts "ERROR: #{err} found in journalctl. Marking as fail."
#			`echo "\nERROR: #{err} found in journalctl. Marking as fail." >> #{$workload_name}.log`
#			$rc = 203 #203 = MCA_ERROR to APEX
#		end
#	}
#        km_copy = `cp kernelmessages.log /root/CommonWorkloads/#{$workload_name}/2.10/run/results`
#else
#	error = "No journalctl log found."
#	File.write('kernelmessages.log', "#{error}")
#	puts "\n=====\n#{error}\n=====\n"
#        km_copy = `cp kernelmessages.log /root/CommonWorkloads/#{$workload_name}/2.10/run/results`
#	$rc = 127
#end
#
#log_contents = File.read("#{$workload_name}.log")
#
#if log_contents.length >= 1
#  result_copy = `cp #{$workload_name}.log /root/CommonWorkloads/#{$workload_name}/2.10/run/results`
#	puts result_copy
#else
#	error = "No log file found."
#	File.write("#{$workload_name}.log", "#{error}")
#	puts "\n=====\n#{error}\n=====\n"
#        result_copy = `cp #{$workload_name}.log /root/CommonWorkloads/#{$workload_name}/2.10/run/results`
#	$rc = 127
#end



exit($rc)
