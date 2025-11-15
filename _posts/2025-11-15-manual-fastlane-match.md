---
layout: post.liquid
title: 'Accessing fastlane match certificates manually'
date: 2025-11-15 14:30:00 +0200
categories: blog
tags: iOS fastlane match CI/CD code-signing automation
description: 'A practical guide to manually accessing and managing iOS code-signing certificates stored in fastlane match repositories using Ruby and the fastlane APIs.'
excerpt: 'Learn how to manually access fastlane match certificates and provisioning profiles outside of automated workflows, useful for debugging and integrating with other tools.'
keywords: 'iOS, fastlane, match, code signing, certificates, provisioning profiles, CI/CD, automation, Ruby, pry'
image: /assets/blog/2025-11-15-manual-fastlane-match/header.webp
author: Philip Niedertscheider
---

I've recently worked a lot with [fastlane match](https://docs.fastlane.tools/actions/match/) for managing iOS code-signing certificates and provisioning profiles in a CI/CD environment. It's a fantastic tool that simplifies the process significantly. However, there are scenarios where you might need to access the certificates and profiles manually, outside of fastlane's automated workflows — for instance, when debugging issues or integrating with other tools.

Here's a quick guide on how to access fastlane match certificates manually:

1. Set up `pry`, the interactive Ruby shell, by adding it to your Gemfile:

   ```ruby
   gem 'pry'
   gem 'fastlane'
   ```

   Then run `bundle install` to install the gem.

2. Open a terminal and start a new interactive Ruby session using `bundle exec pry`, so you have access to the fastlane dependencies:

   ```bash
   bundle exec pry
   ```

3. Load the dependencies `match` and `fastlane_core` in the interactive shell:

   ```ruby
   require 'fastlane_core'
   require 'match'
   ```

4. Configure variables to access your match repository. These include the repository URL, branch, and the `MATCH_PASSWORD` environment variable for decrypting the certificates:

   ```ruby
   git_url = "git@github.com:yourusername/your-match-repo.git" # Your match repository URL
   git_branch = "main" # or your specific branch
   ENV['MATCH_PASSWORD'] = "your_match_password" # Your match password
   ```

   We define the match password by setting it as an environment variable so that the decryption logic can pick it up.

5. Create a `Match::Storage` instance of the type `git` to interact with the match repository:

   ```ruby
   # Create the storage for git (you can also use 'google_cloud', 's3', or 'azure' based on your setup)
   [1] pry(main)> storage = Match::Storage.from_params({
     storage_mode: 'git',
     git_url: git_url,
     git_branch: git_branch
   })
   => #<Match::Storage::GitStorage:0x0000000125d7e940
    @branch="main",
    @clone_branch_directly=nil,
    @git_basic_authorization=nil,
    @git_bearer_authorization=nil,
    @git_full_name=nil,
    @git_private_key=nil,
    @git_url="git@github.com:yourusername/your-match-repo.git",
    @git_user_email=nil,
    @platform="",
    @shallow_clone=nil,
    @skip_docs=nil,
    @type="">

   # Clone the repository to a temporary directory
   [2] pry(main)> storage.download
   [14:38:59]: Cloning remote git repo...
   [14:39:01]: Checking out branch main...
   => ["git checkout main"]

   # Access the working directory where the certificates and profiles are stored
   [3] pry(main)> storage.working_directory
   => "/var/folders/41/rdlp7tmj2x1_vwmp0b_gy9yh0000gn/T/d20251115-3103-av9s91"
   ```

6. Create a `Match::Encryption` instance to handle decryption of the certificates and profiles:

   ```ruby
   # Create the encryption handler for git storage
   [4] pry(main)> encryption = Match::Encryption.for_storage_mode("git", {
     :working_directory=>storage.working_directory
   })
   => #<Match::Encryption::OpenSSL:0x0000000125cb4938
    @force_legacy_encryption=nil,
    @keychain_name=nil,
    @working_directory="/var/folders/41/rdlp7tmj2x1_vwmp0b_gy9yh0000gn/T/d20251115-3103-av9s91">

   # Decrypt the files in the working directory
   [5] pry(main)> encryption.decrypt_files
   [14:45:44]: 🔓  Successfully decrypted certificates repo
   => ["/var/folders/41/rdlp7tmj2x1_vwmp0b_gy9yh0000gn/T/d20251115-3103-av9s91/certs/distribution/S7V6FQBH47.cer",
   "/var/folders/41/rdlp7tmj2x1_vwmp0b_gy9yh0000gn/T/d20251115-3103-av9s91/certs/distribution/S7V6FQBH47.p12",
   "/var/folders/41/rdlp7tmj2x1_vwmp0b_gy9yh0000gn/T/d20251115-3103-av9s91/profiles/appstore/AppStore_dev.philprime.app.mobileprovision"]
   ```

7. Now you can access the decrypted certificates by opening the working directory.

## Bonus: List all branches in the match repository

If you are managing certificates in multiple branches (e.g., for different teams or environments), you can list all branches in the match repository using the following code:

```ruby
[6] pry(main)> Dir.chdir(storage.working_directory) do
    FastlaneCore::CommandExecutor.execute(
      command: "git --no-pager branch --list --no-color -r",
      print_all: true,
      print_command: true
    )
  end.split("\n").map { |b| b.strip.gsub("origin/", "") }
[15:09:47]: $ git --no-pager branch --list --no-color -r
[15:09:47]: ▸   origin/HEAD -> origin/main
[15:09:47]: ▸   origin/main
[15:09:47]: ▸   origin/foo
[15:09:47]: ▸   origin/bar
[15:09:47]: ▸   origin/foobar
=> ["HEAD -> main",
 "main",
 "foo",
 "bar",
 "foobar"]
```
