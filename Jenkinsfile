@Library('pipelineLib@release/2.0.0') _


import com.davita.sdlc.pipeline.BranchFactory
import com.davita.sdlc.pipeline.deployment.DeploymentStrategy
import com.davita.sdlc.pipeline.deployment.DeploymentStrategyFactory

def parameters = [
        [$class: 'StringParameterDefinition', description: 'Env to deploy to', name: 'deployEnv'],
        [$class: 'StringParameterDefinition', description: 'Docker image tag to deploy', name: 'sourceImageTag'],
        [$class: 'StringParameterDefinition', description: 'Branch to deploy', name: 'branchName'],
        [$class: 'StringParameterDefinition', description: 'Microservice to deploy', name: 'microServiceName'],
        [$class: 'StringParameterDefinition', description: 'Project Group (example: MPL)', name: 'projectGroup'],
        [$class: 'StringParameterDefinition', description: 'Project Maintainers', name: 'maintainers', defaultValue: ""],
        [$class: 'StringParameterDefinition', description: 'Deployment Strategy for pipeline', name: 'deploymentStrategy', defaultValue: "default"],
        [$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Set this to true if the service to be deployed retrieves properties from the microservices-config-service. When set to "true", the deployment prompt will allow you to specify which branch for the properties to request.', name: 'usesConfigService']
]

properties([
        [$class: 'RebuildSettings', autoRebuild: false, rebuildDisabled: false],
        [$class: 'ParametersDefinitionProperty', parameterDefinitions: parameters],
        [$class: 'BuildDiscarderProperty', strategy:
                [$class: 'LogRotator', numToKeepStr: '25', artifactNumToKeepStr: '25']
        ],
        pipelineTriggers([])
])

String localBranchName = params.branchName
String deployEnvUc = params.deployEnv.toUpperCase()
String deployEnvLc = params.deployEnv.toLowerCase()
String sourceImageTag = params.sourceImageTag
String deploymentStrategy = params.deploymentStrategy
def maintainers = params.maintainers
String projectId
def servicePackage
def bundleDir = [DEV: 'dev', IDEV: 'dev', QA: 'qa', STAGE: 'stage', PROD: 'prod']

node("DDC") {
    currentBuild.displayName += " ${params.sourceImageTag}"

    stage("Pull DDC artifacts") {
        sh "rm -rf deployment"
        dir("deployment") {
            def artifact = "${params.sourceImageTag}.tgz"
            sh "wget https://artifactory.davita.com/artifactory/Asynchrony/${params.projectGroup}/${params.microServiceName}/${artifact}"
            sh "tar xf ${artifact}"
        }
    }

    stage("Set environment variables") {
        servicePackage = readPackageYml("deployment/")
        projectId = servicePackage.projectId ?: "??"
        env.ENV = deployEnvLc
        env.IMAGE_TAG = params.sourceImageTag
        env.PROJECT_GROUP = params.projectGroup.toLowerCase()
        setEnvironmentVariables(deployEnvLc, servicePackage)
        if (!env.STACK_NAME) {
            // Stack name should be set in the package.yml, this is here for backwards compatibility
            env.STACK_NAME = "${deployEnvLc}_microservices_stack"
            echo "WARNING: stack name was not set in package.yml. Assuming stack ${env.STACK_NAME}, however this functionality may be removed later iteration of the deploy pipeline"
            currentBuild.result = Result.UNSTABLE.toString()
            addWarning("Missing STACK_NAME in package.yml")
        }

        def extractedBundleDir = [:]
        for (item in servicePackage.environmentVariables) {
            def keyLc = item.key.toLowerCase()
            if (!["all", "ci"].contains(keyLc)) {
                extractedBundleDir[item.key.toUpperCase()] = keyLc
            }
        }
        if (extractedBundleDir.size() > 1) {
            bundleDir = extractedBundleDir
        }
    }

    stage("Augment compose file") {
        dir("deployment") {
            sh "sed -i \"s/\\\${REPLICAS}/${env.REPLICAS}/g\" ${servicePackage.composeFile}"
        }
    }
}
def deployStrategy = DeploymentStrategyFactory.getDeploymentStrategy(deploymentStrategy, servicePackage.projectGroup)
def hipchatRooms = []
hipchatRooms += getHipchatRooms(deployStrategy, deployEnvUc)
def readyEmails = getReadyNotifyEmails(deployStrategy, deployEnvUc)
def resultEmails = getResultNotifyEmails(deployStrategy, deployEnvUc, maintainers)



stage("Deploy information") {
    println """
    Deploying ${servicePackage.serviceName}:${params.sourceImageTag} on branch ${params.branchName} to ${params.deployEnv}
    HipChat rooms to notify: $hipchatRooms
    Deploy ready emails to notify: $readyEmails
    Deploy result emails to notify: $resultEmails
    maintainers=${maintainers}
    bundleDir=${bundleDir}"""
}

node("CI") {
    stage("Send Notifications") {
        if (readyEmails) {
            emailext(to: readyEmails,
                    subject: "${servicePackage.serviceName} is ready to deploy to ${deployEnvUc}",
                    body: "${servicePackage.serviceName} on branch ${localBranchName} " +
                            "is waiting to be deployed to ${deployEnvUc}. " +
                            "Please go to ${env.BUILD_URL} to approve the build. " +
                            "If it has stopped running, rebuild and approve. " +
                            "Job name: ${env.JOB_NAME}, Build number: ${env.BUILD_NUMBER}, " +
                            "Image tag: ${params.sourceImageTag}")
        }
        def mentions = deployStrategy.deployReadyHipchatMentionMap().get(deployEnvUc)?: []
        hipchatBuildNotification(hipchatRooms, 'PENDING_APPROVAL', "\n${mentions.join(" ")}")
    }
}

def configLabel = configLabelForEnv(deployEnvUc)

stage("Deploy to ${deployEnvUc}?") {
    try {
        timeout(time: 5, unit: 'MINUTES') {
            def inputParams = params.usesConfigService ? [[$class: 'TextParameterDefinition', defaultValue: configLabel, description: 'Branch/tag for configuration files, use default value if a specific branch/tag is not required', name: 'config label']] : []
            def approver
            if (!["DEV", "IDEV"].contains(deployEnvUc)) {
                ret = input message: "Deploy ${servicePackage.serviceName}:${params.sourceImageTag} to ${deployEnvUc}?", submitter: 'sdlc_sysadmins',
                        parameters: inputParams,
                        submitterParameter: 'APPROVER'
                if (params.usesConfigService) {
                	configLabel = ret['config label']
                	approver = ret['APPROVER']
                }
                else {
                	approver = ret
                }
            } else {
                ret = input message: "Deploy ${servicePackage.serviceName}:${params.sourceImageTag} to ${deployEnvUc}?",
                        parameters: inputParams,
                        submitterParameter: 'APPROVER'
                if (params.usesConfigService) {
                	configLabel = ret['config label']
                	approver = ret['APPROVER']
                }
                else {
                	approver = ret
                }
            }
            println ("Using config branch ${configLabel}")
            if(approver){
                hipchatBuildNotification(hipchatRooms, 'APPROVED', "\nApproved by: ${approver}")
            }
        }
    } catch (error) {
        hipchatBuildNotification(hipchatRooms, 'ABORTED')
        throw error
    }
}

node("DDC") {
    try {

        stage("Pull client bundle") {
            dir("deployment") {
                sh "wget https://artifactory.davita.com/artifactory/ddc/admin-bundles/${bundleDir[deployEnvUc]}/ucp-bundle-admin.zip"
                sh "unzip ucp-bundle-admin.zip"
                env.DOCKER_TLS_VERIFY = 1
                env.DOCKER_CERT_PATH = pwd()
                env.DOCKER_HOST = getDockerHost(deployEnvUc)
            }

        }

        checkServicesForLimit(servicePackage)

        def serviceNames = getServiceNames(servicePackage)
        stage("Deploy ${servicePackage.serviceName} to DDC ${deployEnvUc}") {
            dir('deployment') {
                sh "docker stack deploy --compose-file ${servicePackage.composeFile} ${STACK_NAME}"
            }
        }
        stage("Verify Deployment") {
            for (serviceName in serviceNames) {
                timeout(time: 20, unit: "MINUTES") {
                    def deployStatus = getDeployStatus(serviceName)
                    if (deployStatus == "NO-UPDATE") {
                        println "'docker stack deploy' did not cause service '${serviceName}' to update, forcing an update"
                        sh "docker service update --stop-grace-period=30s --detach=true --force $serviceName"
                        deployStatus = getDeployStatus(serviceName)
                    }
                    while (deployStatus == "updating") {
                        sleep(15)
                        deployStatus = getDeployStatus(serviceName)
                        println "Deploy status for ${serviceName}: $deployStatus"
                    }
                }
                def status = getDeployStatus(serviceName)
                if (!"completed".equalsIgnoreCase(status)) {
                    error("ERROR: Deploy of ${serviceName} failed. Expected status 'completed' but got status '$status'")
                } else {
                    println "Deploy Status for ${serviceName}: $status"
                }
            }
        }

    } catch (e) {
        sendResultEmail(resultEmails, false, localBranchName, deployEnvUc, servicePackage)
        hipchatBuildNotification(hipchatRooms, 'FAILURE')
        throw e
    }
}


node("CI") {
    try {
        kickoffDeploy {
            servicePackageYml = servicePackage
            sourceBranch = BranchFactory.createBranch(localBranchName, "")
            imageTag = sourceImageTag

            deployEnvironments = deployStrategy
                    .calculateNextDeploymentEnvironment(deployEnvUc)
            delegate.deploymentStrategy = deploymentStrategy
            delegate.maintainers = maintainers
        }
    } catch (err) {
        println "Warning: Something went wrong kicking off the next deploy job: $err"
        println "If the job name that is being kicked off, this can be resolved by adding the format of your job name to the package.yml"
        println "Example: 23-view-controller-service-\${ENV}"
        println "\${ENV} will be replaced at runtime with the appropriate environment (dev, qa, etc.)"
        currentBuild.result = Result.UNSTABLE.toString()
        addWarning("Unable to kick off next deploy job")
    }

    hipchatBuildNotification(hipchatRooms, 'SUCCESS')
    sendResultEmail(resultEmails, true, localBranchName, deployEnvUc, servicePackage)
}

def checkServicesForLimit(servicePackage) {
    stage("Validating compose file") {
        def composeFile = readComposeFile(servicePackage)
        for (service in composeFile.services) {
            if (!service.value.deploy?.resources?.containsKey('limits')) {
                println "Service ${service.key} does not have limits set"
                println "${service.value}"
                currentBuild.result = Result.UNSTABLE.toString()
                addWarning("Docker Compose file does not have limits set")
            }
        }
    }
}

def getServiceNames(servicePackage) {
    def serviceNames = []
    def composeFile = readComposeFile(servicePackage)
    for (service in composeFile.services) {
        serviceNames.add("${env.STACK_NAME}_${service.key}")
    }
    return serviceNames
}

def readComposeFile(servicePackage) {
    dir("deployment") {
        def composeFile = readYaml file: servicePackage.composeFile
        return composeFile
    }
}

private void sendResultEmail(String recipient, boolean passed, String branch, String deployEnvUc, servicePackage) {
    if (recipient) {
        String resultString = passed ? "PASSED" : "FAILED"
        String subject = "Deploying ${servicePackage.serviceName} to ${deployEnvUc} ${resultString}"
        String body = "Deployment of ${servicePackage.serviceName} branch ${branch} to ${deployEnvUc} " +
                "with image tag ${params.sourceImageTag} ${resultString}. Link to job: ${env.BUILD_URL}"

        emailext(to: recipient, subject: subject, body: body)
    }
}

private getDeployStatus(serviceName) {
    def inspectJson = sh(
            script: "docker service inspect ${serviceName}",
            returnStdout: true
    ).trim()

    def serviceInspect = new groovy.json.JsonSlurper().parseText(inspectJson)
    def updateStatus = serviceInspect[0]?.get("UpdateStatus")
    if (updateStatus == null) {
        println "DEBUG: service inspect result does not have an UpdateStatus"
        return "NO-UPDATE"
    }
    return updateStatus.get("State")
}

private String configLabelForEnv(String env) {
    def label
    switch (env) {
        case "PROD":
            label = "${params.branchName},master"
            break
        case "STAGE":
            label = "${params.branchName},master"
            break
        case "QA":
            label = "${params.branchName},master"
            break
        case "IDEV":
            label = "develop"
            break
        case "DEV":
            label = "${params.branchName},develop"
            break
    }

    return label
}


private String encodeConfigLabel(String label) {
    return label.replace("/", "(_)")
}

private String getDockerHost(String env) {
    switch (env) {
        case "DEV":
        case "IDEV":
            return "tcp://sea-ucp.davita.corp:443"
        case "QA":
            return "tcp://qa-sea-ucp.davita.corp:443"
        case "STAGE":
            return "tcp://den-ucp.davita.corp:443"
        case "PROD":
            return "tcp://prod-den-ucp.davita.corp:443"
        default:
            throw new Exception("$env has unknown docker host")
    }
}

private void addWarning(String message) {
    if (currentBuild.description) {
        currentBuild.description += message + "<br/>"
    } else {
        currentBuild.description = message + "<br/>"
    }
}

private getHipchatRooms(DeploymentStrategy strategy, String deployEnv) {
    def hipchatRoomMap = [:]
    hipchatRoomMap += strategy.hipchatNotificationMap()
    def rooms = []
    if (hipchatRoomMap.containsKey("ALL")) {
        rooms += hipchatRoomMap.get("ALL")
    }
    if (hipchatRoomMap.containsKey(deployEnv.toUpperCase())) {
        rooms += hipchatRoomMap.get(deployEnv.toUpperCase())
    }
    if (env.HIP_CHAT_ROOMS && env.HIP_CHAT_ROOMS.length() > 0) {
        rooms += env.HIP_CHAT_ROOMS.tokenize(',')
    }
    return rooms.toSet()
}

private getReadyNotifyEmails(DeploymentStrategy strategy, String deployEnv) {
    def emailMap = [:]
    emailMap += strategy.deployReadyEmailNotificationMap()
    def emails = []
    if (emailMap.containsKey(deployEnv.toUpperCase())) {
        emails += emailMap.get(deployEnv.toUpperCase())
    }
    if (env.START_NOTIFY_EMAIL && env.START_NOTIFY_EMAIL.length() > 0) {
        emails += env.START_NOTIFY_EMAIL.tokenize(',')
    }
    return emails.toSet().join(",")
}

private getResultNotifyEmails(DeploymentStrategy strategy, String deployEnv, String maintainers) {
    def emailMap = [:]
    emailMap += strategy.deployResultEmailNotificationMap()
    def emails = []
    emails += maintainers.tokenize(",")
    if (emailMap.containsKey(deployEnv.toUpperCase())) {
        emails += emailMap.get(deployEnv.toUpperCase())
    }
    if (env.RESULT_NOTIFY_EMAIL && env.RESULT_NOTIFY_EMAIL.length() > 0) {
        emails += env.RESULT_NOTIFY_EMAIL.tokenize(',')
    }
    return emails.toSet().join(",")
}
