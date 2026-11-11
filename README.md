# Symfony Deployer Bundle - Easy deployment scripting

This bundle can be used to configure scripts that should be run during your deployment.

# Deployment scripts

## Generate new script

Run `bin/console drenso:deployer:generate`.

## Deployment setup

Just add the following commands to your deployment script, at the required positions:

- Pre-deployment scripts: `bin/console drenso:deployer:pre`
- Post-deployment scripts: `bin/console drenso:deployer:post`
- Back-online-deployment scripts: `bin/console drenso:deployer:back-online`

Or use our the default deployment script.

## Command types

This bundle distinguishes between two main command types: `always` and `once`. Both can be configured for either the `pre`, `post` or `back-online` deployment hook.

## Skipping a step

You can use the `skipIf` method in the script to conditionally skip a script. It will not be marked as executed, so it can still be executed if the condition result changed in the future.

# Deployment pages

This bundle offers a method of generating a simple "We are updating" page.

# Deployment scripting

This bundle offers a standard deployment script which is tailored for use in combination with GitLab CI/CD.
