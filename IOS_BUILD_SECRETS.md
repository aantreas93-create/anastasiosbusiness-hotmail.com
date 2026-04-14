# iOS Build Secrets and Setup

This repository includes a manual GitHub Actions workflow that builds an iOS IPA and uploads it to App Store Connect.

## Running the Workflow

1. Open the repository on GitHub.
2. Open the Actions tab.
3. Select Build iOS IPA.
4. Click Run workflow.
5. Wait for the IPA artifact and App Store Connect upload to finish.

## Required GitHub Secrets

Add these in GitHub at Settings > Secrets and variables > Actions.

### Required for Signing and Upload

- `IOS_DISTRIBUTION_CERT_BASE64`: Base64 string of the Apple Distribution `.p12` file.
- `IOS_DISTRIBUTION_CERT_PASSWORD`: Password used when exporting the `.p12` file.
- `IOS_PROVISIONING_PROFILE_BASE64`: Base64 string of the App Store `.mobileprovision` file.
- `IOS_PROVISIONING_PROFILE_NAME`: Exact provisioning profile name shown in Apple Developer.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `IOS_APP_BUNDLE_IDENTIFIER`: The production iOS bundle identifier for the app.
- `ASC_KEY_ID`: App Store Connect API key ID.
- `ASC_ISSUER_ID`: App Store Connect API issuer ID.
- `ASC_API_KEY_BASE64`: Base64 string of the App Store Connect `.p8` API key file.
- `KEYCHAIN_PASSWORD`: Any strong random password used for the temporary build keychain on the GitHub runner.

## Apple Developer Items You Need First

Before creating the GitHub secrets, make sure you have:

1. A real App ID created in Apple Developer for the final bundle identifier.
2. An Apple Distribution certificate.
3. An App Store provisioning profile linked to that App ID.
4. An App Store Connect API key with permission to upload builds.
5. The correct bundle identifier already configured in the app project.

## Generate the Certificate on Windows

These steps let you prepare the certificate assets from a Windows PC.

### 1. Install OpenSSL

Use Windows Package Manager:

```powershell
winget install ShiningLight.OpenSSL.Light
```

Close and reopen PowerShell after installation.

### 2. Create a Private Key and CSR

Run these commands in a working folder:

```powershell
openssl genrsa -out ios_distribution.key 2048
openssl req -new -key ios_distribution.key -out ios_distribution.csr -subj "/emailAddress=you@example.com, CN=Your Name, C=US"
```

Upload `ios_distribution.csr` in Apple Developer when creating the Apple Distribution certificate.

### 3. Download the Certificate

In Apple Developer:

1. Open Certificates, Identifiers & Profiles.
2. Open Certificates.
3. Create a new `Apple Distribution` certificate.
4. Upload `ios_distribution.csr`.
5. Download the generated certificate as `ios_distribution.cer`.

### 4. Export the Certificate as P12

Convert the downloaded certificate and private key into a `.p12` file:

```powershell
$p12Password = Read-Host "Enter a password for the iOS distribution p12" -AsSecureString
$plainPassword = [System.Net.NetworkCredential]::new('', $p12Password).Password
openssl pkcs12 -export -inkey ios_distribution.key -in ios_distribution.cer -out ios_distribution.p12 -passout pass:$plainPassword
```

Save the password. It becomes the `IOS_DISTRIBUTION_CERT_PASSWORD` GitHub secret.

## Generate the Provisioning Profile

In Apple Developer:

1. Open Certificates, Identifiers & Profiles.
2. Open Profiles.
3. Create a new profile of type `App Store Connect`.
4. Select the App ID that matches the app bundle identifier.
5. Select the Apple Distribution certificate you created.
6. Name the profile.
7. Download the `.mobileprovision` file.

The exact profile name becomes `IOS_PROVISIONING_PROFILE_NAME`.

## Generate the App Store Connect API Key

In App Store Connect:

1. Open Users and Access.
2. Open the Integrations or API Keys section.
3. Create a new API key.
4. Save the `.p8` file immediately.
5. Copy the Key ID.
6. Copy the Issuer ID.

Store those values in `ASC_KEY_ID` and `ASC_ISSUER_ID`.

## Find the Apple Team ID

In Apple Developer:

1. Sign in.
2. Open Membership.
3. Copy the Team ID.

Store that value in `APPLE_TEAM_ID`.

## Base64 Encode the Files in PowerShell

Run these commands from the folder that contains the downloaded files.

### Distribution Certificate

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\ios_distribution.p12")) | Set-Content -NoNewline ".\IOS_DISTRIBUTION_CERT_BASE64.txt"
```

### Provisioning Profile

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\YourProfile.mobileprovision")) | Set-Content -NoNewline ".\IOS_PROVISIONING_PROFILE_BASE64.txt"
```

### App Store Connect API Key

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\AuthKey_ABCDE12345.p8")) | Set-Content -NoNewline ".\ASC_API_KEY_BASE64.txt"
```

Open each generated `.txt` file and paste the single-line contents into the matching GitHub secret.

## Generate a Keychain Password in PowerShell

Use this command to create a strong random password for `KEYCHAIN_PASSWORD`:

```powershell
[Convert]::ToBase64String((1..48 | ForEach-Object { Get-Random -Maximum 256 }))
```

## Bundle Identifier Setup

The `IOS_APP_BUNDLE_IDENTIFIER` secret must match all of the following:

1. The Apple App ID.
2. The provisioning profile.
3. The Xcode project bundle identifier.
4. The Firebase iOS app configuration if Firebase is used on iOS.

If those values do not match, the build or upload will fail.

## Recommended Pre-Flight Checks

Before running the workflow for the first time:

1. Confirm the iOS bundle identifier is final.
2. Confirm the provisioning profile was created for that exact bundle identifier.
3. Confirm the certificate is an Apple Distribution certificate.
4. Confirm the App Store Connect API key has upload access.
5. Confirm the app version and build number strategy is acceptable for App Store submissions.
6. Confirm all required iOS capabilities are enabled in Apple Developer for any services the app uses.