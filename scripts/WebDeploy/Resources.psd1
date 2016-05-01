ConvertFrom-StringData @'

Info=Information

Warning=Warning

Error=Error

GrantedPermissions=Granted {0} permissions to {1} on path: {2}

NotGrantedPermissions=Could not grant {0} permissions to {1} on path: {2}

IsAdmin=Confirmed that {0} is a member of the local Administrators group.

CreatedUser=Could not find an existing user account, created local user: {0}

AddedUserAsAdmin=Added {0} to the local Administrators group

CheckIIS7Installed=Failed to load Microsoft.Web.*.dll.  Please verify that IIS 7 is installed.

RuleNotCreated=Skipped creating rule for {0} as it already exists.

CreatedRule=Created delegation rule for provider(s): {0}

NotServerOS=The current SKU is invalid. This script should only be used on a server SKU.

WDeployNotInstalled=Web Deploy must be installed before running this script

HandlerNotInstalled=The IIS 7 Deployment Handler feature of Web Deploy must be installed. Please add this feature in Add/Remove Programs.

SharedConfigInUse=Cannot run this script when Shared Config is enabled.

NoPasswordForGivenUser=Password is required when a user is specified. Please specify password for {0} and try again.

PasswordWillBeReset=No password is specified for {0}. Since ignore reset errors is set, the user password will be reset.

FailedToValidateUserWithSpecifiedPassword=Could not validate user {0} with the specified password.

UpdatedRunAsForSpecificUser=Updated the password for the runAs user {1} specified in the rule for {0}

SiteCreationFailed=Failed to create site. Script will exit now.

FailedToGrantUserAccessToSite=Could not grant IIS Manager permissions for {0} on site {1}.

GrantedUserAccessToSite=Granted IIS Manager permissions for {0} on site {1}.

UserHasAccessToSite=Confirmed that {0} has IIS Manager permissions for site {1}.

FailedToAccessScriptsFolder=Could not access publish settings file save location: {0}. Settings will not be saved.

SavingPublishXmlToPath=Saved publish settings at {0}

FailedToWritePublishSettingsFile=Failed to create publish settings file at {0}.

AppPoolCreated=Created application pool {0}.

AppPoolExists=Application Pool {0} already exists. The application pool may be in use by other applications. It is recommended to have one application pool per site or to disable any appPoolPipeline, appPoolNetFx or recycleApp delegation rules. 

SiteCreated=Created site {0}.

SiteAppPoolUpdated=Confirmed site {0} exists. Application pool for site changed to {1}.

SiteExists=Confirmed site {0} exists and is using application pool {1}.

SiteVirtualDirectoryExists=Skipping site directory creation as directory {0} already exists.  There may be existing content in this directory.

FailedToCreateLogin=Failed to create login {0}

LoginExists=Login {0} already exists.

FailedToCreateDbUser=Failed to create user {0}

DbUserExists=Database User {0} already exists.

FailedToSetupDatabase=Failed to setup database {0}

FailedToCreateDatabase=Failed to create database {0}

DbExists=Database {0} already exists.

SmoNotInstalled=Could not create database. Please make sure that Microsoft SQL Server Management Objects (Version 10 or higher) is installed.

NoPasswordForExistingUserForPublish=Deployment user password was not specified and will not be saved in publish settings file.

CouldNotLoadDeploymentDll=Could not load Microsoft.Web.Deployment.dll.  Please ensure Web Deploy is installed.

ProviderDoesNotExist=The provider {0} is not installed on the system.

CannotSetAndAddProviders=Cannot set both -SetExcludedProviders and -AddExcludedProviders.

ServerBackupConfigChanges=Making server backup configuration changes.

SiteBackupConfigChanges=Making backup configuration changes for site {0}.

BackupSettingEnabled=Setting Enabled to {0}.

BackupSettingPath=Setting Backup Path to: {0}.

BackupSettingPathWarn=Remember to add the proper user permissions to your backup path so that backups can be written there.

BackupSettingNumber=Setting Number of Backups to: {0}.

BackupSettingContinueSync=Setting ContinueSyncOnBackupFailure to {0}.

BackupAddingProviders=Adding provider {0} to ExcludedProviders collection.

BackupSettingCanSetEnabled=Setting CanSetEnabled to {0}.

BackupSettingCanSetNumBackups=Setting CanSetNumBackups to {0}.

BackupSettingCanSetContinueSync=Setting CanSetContinueSyncOnBackupFailure to {0}.

BackupSettingCanSetExcludedProviders=Setting CanSetExcludedProviders to {0}.

BackupResetServerConfig=Resetting server-level backup configuration.

BackupResetSiteConfig=Resetting backup configuration for site {0}.

BackupTurningOn=Turning Backup Feature On.  In order for backups to execute, they still need to be enabled at either the server or site level.

BackupTurningOff=Turning Backup Feature Off.

WritingToLogFile=Writing to log file: {0}.

'@ 