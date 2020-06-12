:ok = LocalCluster.start()

Application.ensure_all_started(:maxi_taxi)

ExUnit.start()
