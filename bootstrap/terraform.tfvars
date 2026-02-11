# One subscription per environment. Shared resources (state, ACR) go in the dev subscription.
# Use the same ID for all three if you only have one subscription.
subscription_ids = {
  dev  = "bb67a95f-185c-4a8b-ae32-9f35da2c9465"
  sit  = "0dbb4aef-c5e3-4812-8033-900f482e463a"
  prod = "10f3082b-1435-4978-8f43-1c857bc3402f"
}

location       = "westeurope"
location_short = "weu"
github_org     = "ramonbrbs"
github_repo    = "Zetdo.Infra"
