.PHONY: vagrant-deploy vagrant-init vagrant-provision vagrant-destroy

vagrant-init:
	vagrant init

vagrant-deploy:
	#
	#=============================================
	# Deploying VM
	#=============================================
	#
	vagrant up

vagrant-provision:
	#
	#=============================================
	# Configure with ansible-playbook 
	#=============================================
	#
	vagrant provision

vagrant-destroy:
	#
	#=============================================
	# Kill it with fire
	#=============================================
	#
	vagrant destroy --force
