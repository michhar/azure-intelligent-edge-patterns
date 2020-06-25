@ECHO OFF
SET AZURE_CORE_NO_COLOR=
SET AZURE_CORE_ONLY_SHOW_ERRORS=True

REM ARM deployment script for Custom Vison solution (Free SKU)
SET custom-vision-arm=deploy-custom-vision-arm.json
REM edge-deployment-json is the template, 
SET edge-deployment-json=deployment.amd64.json
REM edge-deploy-json is the deployment description with keys and endpoints added
SET edge-deploy-json=deploy.modules.json
REM the solution resource group name
SET rg-name=visiononedge-rg

REM az-subscripton-name = The friendly name of the Azure subscription
REM iot-hub-name = The IoT Hub that corisponds to the ASE device
REM edge-device-id = The device id of the ASE device
REM cv-training-api-key = The Custom Vision service training key
REM cv-training-endpoint = The Custom Vision service end point
REM cpuGpu = CPU or GPU deployment

SETLOCAL ENABLEDELAYEDEXPANSION

REM ############################## Install Prereqs ##############################  

ECHO Installing / updating the IoT extension
CALL az extension add --name azure-iot
IF NOT !errorlevel! == 0 (
  REM Azure CLI is not installed.  It has an MSI installer on Windows, or is available over REST.
  ECHO.
  ECHO It looks like Azure CLI is not installed.  Please install it from: 
  ECHO https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows
  ECHO and try again
  ECHO.
  ECHO Press any key to exit...
  PAUSE > noOutput
  GOTO :eof
)

REM ############################## Get Tenant ###################################

REM Remove the header and ---- from output list - start good var data at var1
SET count=-1
ECHO Logging on to Azure...
FOR /F "tokens=* USEBACKQ" %%F IN (`az login -o table --query [].name`) DO (
  SET var!count!=%%F
  SET /a count=!count!+1
)
REM Strip off last increment
SET /a count=!count!-1
REM Only one option so no need to prompt for choice
IF !count! leq 1 (
    CALL az account set --subscription "!var1!"
) ELSE (
    REM This assumes an upper limit of 26 on any list to be chosen from
    REM Underscore is necessary as all other constructs are 1 based so lines up with 1 based for loop next
    SET alpha=_abcdefghijklmnopqrstuvwxyz
    FOR /L %%G IN (1,1,!count!) DO (
        SET char=!alpha:~%%G,1!
        ECHO !char!     !var%%G!
    )
    ECHO.
    SET choose=!alpha:~1,%count%!
    CHOICE /c !choose! /m "Choose the letter corisponding to your tenant" /n
    CALL SET az-subscripton-name=%%var!errorlevel!%%
    CALL ECHO "you chose:" "!az-subscripton-name!"
    CALL az account set --subscription "!az-subscripton-name!" --only-show-errors
)

REM ############################## Install Custom Vision ###########################

REM ECHO You can use your existing Custom Vision service, or create a new one
REM CHOICE /c yn /m "Would you like to use an existing Custom Vision Service?" /n

REM REM Using goto here due to issues with delayed expansion
REM IF %errorlevel%==1 ( GOTO :EXISTINGCV )
REM ECHO Installing the Custom Vision Service
REM ECHO.
REM SET loc1=eastus
REM SET loc2=westus2
REM SET loc3=southcentralus
REM SET loc4=northcentralus

REM ECHO a      %loc1%
REM ECHO b      %loc2%
REM ECHO c      %loc3%
REM ECHO d      %loc4%
REM ECHO.
REM CHOICE /c abcd /m "choose the location" /n

REM SET location=!loc%errorlevel%!

REM ECHO you chose: %location%

REM ECHO Creating resource group - %rg-name%
REM call az group create -l %location% -n %rg-name%

REM ECHO Creating Custom Vision Service
REM SET count=0
REM REM Need to note in the documentation that only one free service per subscription can be created.  An existing one results in an error.
REM FOR /F "tokens=* USEBACKQ" %%F IN (`az deployment group create --resource-group %rg-name% --template-file %custom-vision-arm%
REM     --query properties.outputs.*.value -o table --parameters "{ \"location\": { \"value\": \"%location%\" } }"`) DO ( 
REM   REM to do: figure out the format for retrieving the training and predition keys here
REM   SET out!count!=%%F
REM   SET /a count=!count!+1
REM )
REM IF !count! == 0 (
REM     ECHO.
REM     ECHO Deployment failed.  Please check if you already have a free version of Custom Vision installed.
REM     ECHO Press any key to exit...
REM     PAUSE > noOutput
REM     GOTO :eof
REM )

REM REM Set the Custom Vision variables
REM SET cv-training-api-key=!out2!
REM SET cv-training-endpoint=!out3!

REM ECHO API Key: %cv-training-api-key%
REM ECHO Endpoint: %cv-training-endpoint%

REM GOTO :NOEXISTINGCV
REM :EXISTINGCV
REM SET /P cv-training-endpoint="Please enter your Custom Vision endpoint: "
REM SET /P cv-training-api-key="Please enter your Custom Vision Key: "

REM :NOEXISTINGCV

REM ############################## Get IoT Hub #####################################

REM Remove the header and ---- from output list - start good var data at var1
SET count=-1
ECHO listing IoT Hubs
FOR /F "tokens=* USEBACKQ" %%F IN (`az iot hub list --only-show-errors -o table --query [].name`) DO (
  SET var!count!=%%F
  SET /a count=!count!+1
)
REM Strip off last increment
SET /a count=!count!-1

IF !count! leq 0 (
  ECHO IoTHub not found
  ECHO Sorry, this demo requires that you have an existing IoTHub and registered Azure Stack Edge Device
  ECHO Press any key to exit...
  PAUSE > noOutput
  GOTO :eof
)
REM Only one option so no need to prompt for choice
IF !count! == 1 (
    CHOICE /c YN /m "please confirm install to %var1% hub"
    IF !errorlevel!==2 ( 
      GOTO :eof 
    )
    SET iot-hub-name=%var1%
) ELSE (
    REM This assumes an upper limit of 26 on any list to be chosen from
    REM Underscore is necessary as all other constructs are 1 based so lines up with 1 based for loop next
    SET alpha=_abcdefghijklmnopqrstuvwxyz
    FOR /L %%G IN (1,1,!count!) DO (
        SET char=!alpha:~%%G,1!
        ECHO !char!     !var%%G!
    )
    ECHO.
    SET choose=!alpha:~1,%count%!
    CHOICE /c !choose! /m "Choose the letter corisponding to your iothub" /n
    CALL SET iot-hub-name=%%var!errorlevel!%%
    CALL ECHO you chose: !iot-hub-name!
)

REM ############################## Get Device #####################################

REM Remove the header and ---- from output list - start good var data at var1
SET count=-1
ECHO getting devices
REM query parameter retrieves only edge devices
FOR /F "tokens=* USEBACKQ" %%F IN (`az iot hub device-identity list -n !iot-hub-name! -o table --query [?capabilities.iotEdge].[deviceId]`) DO (
  SET var!count!=%%F
  SET /a count=!count!+1
)
REM Strip off last increment
SET /a count=!count!-1

IF !count! leq 0 (
  ECHO No edge device found
  ECHO Sorry, this demo requires that you have an existing IoTHub and registered Azure Stack Edge Device
  ECHO Press any key to exit...
  PAUSE > noOutput
  GOTO :eof
)
REM Only one option so no need to prompt for choice
IF !count! == 1 (
    CHOICE /c YN /m "please confirm install to %var1% device"
    IF !errorlevel!==2 ( 
      GOTO :eof 
    )
    SET edge-device-id=%var1%
) ELSE (
    REM This assumes an upper limit of 26 on any list to be chosen from
    REM Underscore is necessary as all other constructs are 1 based so lines up with 1 based for loop next
    SET alpha=_abcdefghijklmnopqrstuvwxyz
    FOR /L %%G IN (1,1,!count!) DO (
        SET char=!alpha:~%%G,1!
        ECHO !char!     !var%%G!
    )
    ECHO.
    SET choose=!alpha:~1,%count%!
    CHOICE /c !choose! /m "Choose the letter corisponding to your iot device" /n
    CALL SET edge-device-id=%%var!errorlevel!%%
    CALL ECHO you chose: !edge-device-id!
)

REM ################################ Check for GPU ###########################################
CHOICE /c yn /m "Does your Azure Stack Edge device have a GPU?" /n

REM Using goto here due to issues with delayed expansion
IF %errorlevel%==1 ( SET cpuGpu=gpu) ELSE ( SET cpuGpu=cpu)
IF %cpuGpu%==gpu ( SET runtime=nvidia) ELSE ( SET runtime=runc)

REM ############################## Write Config ############################################

REM clear file if it exists
ECHO. > %edge-deploy-json%

FOR /f "delims=" %%i IN (%edge-deployment-json%) DO (
    SET "line=%%i"
    SET "line=!line:<Training API Key>=%cv-training-api-key%!"
    SET "line=!line:<Training Endpoint>=%cv-training-endpoint%!"
    SET "line=!line:<cpu or gpu>=%cpuGpu%!"
    SET "line=!line:<Docker Runtime>=%runtime%!"
    ECHO !line! >> %edge-deploy-json%
)

REM ############################## Deploy Edge Modules #####################################

ECHO Deploying conatiners to Azure Stack Edge
ECHO This will take > 10 min at normal connection speeds.  Status can be checked on the Azure Stack Edge device
SET count=-1
FOR /F "tokens=* USEBACKQ" %%F IN (`az iot edge set-modules --device-id %edge-device-id% --hub-name %iot-hub-name% --content %edge-deploy-json%`) DO (
  SET var!count!=%%F
  SET /a count=!count!+1
)
ECHO installation complete

ECHO solution scheduled to deploy on the %edge-device-id% device, from the %iot-hub-name% hub

ENDLOCAL