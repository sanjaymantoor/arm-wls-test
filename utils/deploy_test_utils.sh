# utility functions for deploying offers and executing tests

# This function verifies git version as per the required version
# Pass the required git version to be verified
function gitVersionCheck()
{
	REQ_GIT_VERSION=$1
	GIT_VER=`git --version`
	echo "Verifying ${GIT_VER} with required version ${REQ_GIT_VERSION}"
	if [[ "$GIT_VER" > "$REQ_GIT_VERSION" ]];
	then
		echo "Git version is higher than required version  $REQ_GIT_VERSION"
	else
		logMessage "Git version is lower than the required version  $REQ_GIT_VERSION"
	fi
}


#This function checks the availability of jq tool
function jqVersionCheck()
{
	JQ_VER=`jq --version`
	if [[ $? != 0 ]] ; then
		echo "jq tool is not available"
		exit 1
	fi
	echo "JQ version : $JQ_VER"
		
}

# Formats the log message
function logMessage() 
{
	echo "##### $* ####"
}

# Verifies shell command is executed properly or not
function checkSuccess()
{
	error_code=$1
	message=$2
	if [ $error_code != 0 ]; then
		logMessage "FAILED: $message"
		exit 1
	fi
}

# Cloning git repository
function cloneTestRepository()
{
	gitRepoURL=$1
	workDirectory=$2
	cd ${workDirectory}
	echo "Cloning repository ${gitRepoURL} at ${workDirectory}"
	git clone $gitRepoURL
	checkSuccess $? "Git cloning for $gitRepoURL failed"
}

# Hardcode PIDS
function hardCodePIDs()
{
	gitWorkDirectory=$1
	cd ${gitWorkDirectory}/weblogic-azure
	pwd
	pidKeys=`cat resources/pid.properties | cut -f1 -d"=" | grep -v '#' | grep -v "^$"`
	for pidKey in $pidKeys
	do
		value=`cat resources/pid.properties | grep -w "^$pidKey" | cut -f2 -d"="`
		pidString='${'${pidKey}'}'
		jsonFiles=`find . -name *.json`
		for jsonFile in $jsonFiles
		do
			echo "Replacing $pidString with $value in $jsonFile"
			sed -i "s|$pidString|$value|g" $jsonFile 
		done
	done
	pidKeys=`cat resources/azure-common.properties | cut -f1 -d"=" | grep -v '#' | grep -v "^$"`
	for pidKey in $pidKeys
	do
		value=`cat resources/azure-common.properties | grep -w "^$pidKey" | cut -f2 -d"="`
		pidString='${'${pidKey}'}'
		jsonFiles=`find . -name *.json`
		for jsonFile in $jsonFiles
		do
			echo "Replacing $pidString with $value in $jsonFile"
			sed -i "s|$pidString|$value|g" $jsonFile 
		done
	done
	git status
	checkSuccess $? "Git status failed"
}

# Create test branch 
function createNewGitBranch()
{
	gitRepoURL=$1
	gitWorkDirectory=$2
	testBranchName=$3
	gitUser=$4
	gitToken=$5
	gitUserEmail=$6
	skuUrnVersion=$7
	gitGlobalSettings $gitUserEmail $gitUser
	cloneTestRepository ${gitRepoURL} ${gitWorkDirectory}
	cd ${gitWorkDirectory}/weblogic-azure
	echo "Creating test branch ${testBranchName}"
	git checkout -b ${testBranchName}
	git remote add ${testBranchName} ${gitRepoURL}
	#updateSKU $skuUrnVersion $gitWorkDirectory
	#addTestDeployment $gitWorkDirectory
	#updateOfferName $gitWorkDirector
	hardCodePIDs ${gitWorkDirectory}	 
	cd ${gitWorkDirectory}/weblogic-azure
    git commit -a -m "Hardcode pids"
    echo "git push https://${gitUser}:${gitToken}@github.com/${gitUser}/weblogic-azure.git --all"
    #git push origin ${testBranchName} --repo https://${gitUser}:${gitToken}@github.com/${gitUser}/weblogic-azure.git
    git push https://${gitUser}:${gitToken}@github.com/${gitUser}/weblogic-azure.git --all
    checkSuccess $? "Pushing changes to git failed"
}

# Delete test branch
function deleteGitBranch()
{
	gitWorkDirectory=$1
	gitUser=$2
	gitToken=$3
	testBranchName=$4
	cd $gitWorkDirectory/weblogic-azure
	git push https://${gitToken}@github.com/${gitUser}/weblogic-azure.git -f --delete ${testBranchName}
	checkSuccess $? "Delete brach ${testBranchName} failed"
}


# Set GIT global settings
function gitGlobalSettings()
{
	gitUserEmail=$1
	gitUser=$2
	git config --global core.longpaths true
	git config --global user.email "${gitUserEmail}"
	git config --global user.name "${gitUser}"
}


# Check azure cli availability
function azureCLICheck()
{
	az version
	checkSuccess $? "Unable to find azure cli"
	az account show
	checkSuccess $? "Azure login details is not available"
}

#deploy admin offer
function deployAdminOffer()
{
	parametersJsonFilePath=$1
	resourceGroupName=$2
	rawMainTemplateURL=$3
	location=$4
	skuUrnVersion=$5
	IFS=',' additionalOfferParams=( ${6} )
	unset IFS	
	additionalOfferParams=$( printf "%s " "${additionalOfferParams[@]}")
	createAZresourceGroup $resourceGroupName $location
	echo "Deploying admin offer"
	echo "az group deployment create --resource-group $resourceGroupName --template-uri $rawMainTemplateURL --parameters $parametersJsonFilePath  skuUrnVersion=${skuUrnVersion} ${additionalOfferParams} location=$location"  
	az group deployment create --resource-group $resourceGroupName --template-uri $rawMainTemplateURL --parameters $parametersJsonFilePath  skuUrnVersion=${skuUrnVersion} ${additionalOfferParams} location=$location
	if [[ $? != 0 ]];
	then
		echo "Azure WebLogic deployment failed"
		exit 1
	fi
}

#deploy cluster offer
function deployClusterOffer()
{
	parametersJsonFilePath=$1
	resourceGroupName=$2
	rawMainTemplateURL=$3
	location=$4
	skuUrnVersion=$5
	IFS=',' additionalOfferParams=( ${6} )
	unset IFS	
	additionalOfferParams=$( printf "%s " "${additionalOfferParams[@]}")
	createAZresourceGroup $resourceGroupName $location
	echo "Deploying cluster offer"
	echo "az group deployment create --resource-group $resourceGroupName --template-uri $rawMainTemplateURL --parameters $parametersJsonFilePath  skuUrnVersion=${skuUrnVersion} ${additionalOfferParams} location=$location"  
	az group deployment create --resource-group $resourceGroupName --template-uri $rawMainTemplateURL --parameters $parametersJsonFilePath  skuUrnVersion=${skuUrnVersion} ${additionalOfferParams} location=$location
	if [[ $? != 0 ]];
	then
		echo "Azure WebLogic deployment failed"
		exit 1
	fi
}


# create azure resource group
function createAZresourceGroup()
{
	resourceGroupName=$1
	location=$2
	echo "Creating resource group $resourceGroupName"
	echo "az group create --name $resourceGroupName --location  $location"
	az group create --name $resourceGroupName --location  $location
}


#This function to execute pre-defined tests as part of the repository
#Tests executed as per argument supplied
function testOffer()
{
	testRepoURL=$1
	rawMainTemplateURL=$2
	resourceGroupName=$3
	runTests=$4
	testInputFile=$5
	testScript=$6
	location=$7
	artifactLocation=$8
	echo "location=$location"
	IFS=',' additionalTestParams=( $9 )
	unset IFS
	additionalTestParams=$( printf "%s " "${additionalTestParams[@]}")
	echo "Getting adminvm name by querying the deployed resource group"
	adminVMName=$(az deployment group show -g $resourceGroupName -n mainTemplate |jq '.properties.outputs.adminVMName.value' | sed 's/\"//g')
	echo "Admin VM is set to $adminVMName"
	echo "additionalTestParams : ${additionalTestParams}"
	echo "Testing the offer with $testScript"
	echo "az group deployment create --resource-group $resourceGroupName --template-uri $rawMainTemplateURL --parameters testScenarios=$runTests testInputPropertyFile=$testInputFile testScriptFileName=$testScript testArtifactRepo=$testRepoURL location=$location _artifactsLocation=$artifactLocation ${additionalTestParams} adminVMName=${adminVMName}"
 	az group deployment create --resource-group $resourceGroupName --template-uri $rawMainTemplateURL --parameters testScenarios=$runTests testInputPropertyFile=$testInputFile testScriptFileName=$testScript testArtifactRepo=$testRepoURL location=$location _artifactsLocation=$artifactLocation ${additionalTestParams} adminVMName=${adminVMName}
	if [[ $? != 0 ]];
	then
		echo "Azure test deployment failed"
		exit 1
	fi
}	

# Remote testing
function remoteTests()
{
	testScenarios=$1
	resourceGroupName=$2
	testInputFileName=$3
	currentDirectory=`pwd`
	rm -f summary.log | true
	echo "Starting Remote test execution"
	IFS=',' testLists=( $testScenarios )
	for test in ${testLists[*]}
    do
		case "${test}" in
		"appgateway")
			echo "Executing appgateway tests"
			echo "sh $currentDirectory/../appgateway/appgateway_test.sh -i $testInputFileName"
			sh $currentDirectory/../appgateway/appgateway_test.sh -i $currentDirectory/../test_input/$testInputFileName -r $resourceGroupName > ${currentDirectory}/${test}.log 2>&1
			;;
		"ohs")
			echo "Executing OHS tests"
			echo "sh $currentDirectory/../ohs/ohs_test.sh -i $testInputFileName"
			sh $currentDirectory/../ohs/ohs_test.sh -i $currentDirectory/../test_input/$testInputFileName -r $resourceGroupName > ${currentDirectory}/${test}.log 2>&1
			;;
		esac
		
		if [ -f ${currentDirectory}/${test}.log ];
		then
			echo "================ ${test} Execution Details ================ " >> ${currentDirectory}/summary.log
        	cat ${test}.log | grep "FAILURE" >> ${currentDirectory}/summary.log
        	cat ${test}.log | grep "TEST EXECUTION SUMMARY" >> ${currentDirectory}/summary.log
        	cat ${test}.log | grep "++" >> ${currentDirectory}/summary.log
        	cat ${test}.log | grep "NO OF TEST PASSED:" >> ${currentDirectory}/summary.log
        	cat ${test}.log | grep "NO OF TEST FAILED:" >> ${currentDirectory}/summary.log
        fi
	done
	
	if [ -f ${currentDirectory}/summary.log ];
	then
		echo "============================"
		cat ${currentDirectory}/summary.log
		echo "============================"
		cat ${currentDirectory}/summary.log | grep "FAILURE"
		if [ $? == 0 ]; then
			echo "----------------------------"
			echo "| SOME REMOTE TESTS FAILED |"
			echo "----------------------------" 
			exit 1
		else
			echo "----------------------------"
			echo "| ALL REMOTE TESTS PASSED  |"
			echo "----------------------------"
			exit 0
		fi	
	else
		echo "============================"
		echo "| REMOTE TESTS NOT EXECUTED|"
		echo "============================"
		exit 1 
	fi
}

# This function updates offer images to sku to offer template files
function updateSKU()
{
	skuUrnVersion=$1
	gitWorkDirectory=$2
	cd ${gitWorkDirectory}/weblogic-azure
	#templatesList=`grep -rn '"skuUrnVersion": {' | cut -f1 -d":" | sort| uniq`
	templatesList="weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/mainTemplate.json  
				   weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/nestedtemplates/adminTemplateForCustomSSL.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/nestedtemplates/adminTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/mainTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/nestedtemplates/clusterCustomSSLTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/nestedtemplates/clusterTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/nestedtemplates/coherenceTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/mainTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/nestedweblogic-azureTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/nestedtemplates/clusterTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/nestedtemplates/coherenceTemplate.json"
	for templateFile in $templatesList
	do
		printf "Updating $templateFile for skuUrnVersion\n"
		jq '.parameters.skuUrnVersion.defaultValue="'$skuUrnVersion'"' $templateFile > ${templateFile}.tmp
		mv ${templateFile}.tmp $templateFile
		jq '.parameters.skuUrnVersion.allowedValues="'$skuUrnVersion'"' $templateFile > ${templateFile}.tmp
		mv ${templateFile}.tmp $templateFile
	done
}

# This function adds deployments section to offer template files
function addTestDeployment()
{
 
 	gitWorkDirectory=$1
	cd ${gitWorkDirectory}/weblogic-azure
	templatesList="weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/nestedtemplates/adminTemplateForCustomSSL.json
				   weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/nestedtemplates/adminTemplate.json
				   weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/nestedtemplates/clusterCustomSSLTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/nestedtemplates/clusterTemplate.json
				   weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/nestedtemplates/clusterCustomSSLTemplate.json
				   weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/nestedtemplates/clusterTemplate.json"
	for templateFile in $templatesList
	do
		printf "Adding deployments section for test offers"
		length=`jq '.resources | length' $templateFile`
		jq '.resources['$length'] |= . +  { 
				"type": "Microsoft.Resources/deployments", 
				"apiVersion": "${azure.apiVersion}",
				"name": "wls-base-image",
				"condition": "[if(contains(variables('name_linuxImageOfferSKU'), 'test'), bool('true'), bool('false'))]",
				"dependsOn": [
					"[resourceId('Microsoft.Compute/virtualMachines/extensions', parameters('adminVMName'), 'newuserscript')]"
				],
				"properties": {
					"mode": "Incremental",
					"template": {
						"$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
						"contentVersion": "1.0.0.0",
						"resources": [
						]
					}
				}
	  }' $templateFile > $templateFile.tmp
	  mv $templateFile.tmp $templateFile
	done
}

# This function replaces const_imageOffer value in template files
function updateOfferName()
{
	gitWorkDirectory=$1
	cd ${gitWorkDirectory}/weblogic-azure
		templatesList="weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/mainTemplate.json  
				   weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/nestedtemplates/adminTemplateForCustomSSL.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-admin/src/main/arm/nestedtemplates/adminTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/mainTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/nestedtemplates/clusterCustomSSLTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/nestedtemplates/clusterTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-cluster/arm-oraclelinux-wls-cluster/src/main/arm/nestedtemplates/coherenceTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/mainTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/nestedtemplates/clusterCustomSSLTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/nestedtemplates/clusterTemplate.json 
				   weblogic-azure-vm/arm-oraclelinux-wls-dynamic-cluster/arm-oraclelinux-wls-dynamic-cluster/src/main/arm/nestedtemplates/coherenceTemplate.json"
	for templateFile in $templatesList
	do
		jq '.variables.const_imageOffer="wls-base-image"' $templateFile > $templateFile.tmp
		mv $templateFile.tmp $templateFile
	done

}

