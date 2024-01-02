# Memory Assessment Services (MAS) Dashboard

This folder contains the SQL scripts for the MAS Dashboard([https://future.nhs.uk/DCNFutures/view?objectID=40667984])

Please note this information is experimental and it is only intended for use for management purposes.

There are two folders in the MAS Dashboard folder:
* NCDR
* UDAL

NCDR stands for the National Commissioning Data Repository and UDAL stands for Unified Data Access Layer.
  
We are currently transitioning from using NCDR for running our scripts to UDAL. However, at the moment we are still using NCDR for the monthly refreshes of the MAS Dashboard, so please refer to the scripts in the NCDR folder.

The NCDR folder also has the script for producing the LSOA lookup table used in the population script. There is no UDAL version of this script as the LSOA lookup table was manually copied to UDAL for use there.

Both folders contain three main scripts (suffixed with step 1, step 2, step 3 and 4) for calculating the following: 

* open referrals
* open referrals with no contact
* open referrals with a care plan
* new referrals
* discharges
* wait times from referral to first contact
* wait times from referral to diagnosis
