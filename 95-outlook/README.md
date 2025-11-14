# 95 - Outlook

This section concludes the self-hosting workshop. However, there is much more to learn! If you have questions or would like to explore a topic, feel free to ask, and we can take a look at it if time permits.

If you decide to start self-hosting at home, I hope the knowledge you gained will help you to get started and have confidence in your infrastructure.

# Continue on the Homelab Journey

In case you are interested and want to start your own homelab, but are unsure how you could proceed, we listed some topics below that might be interesting to explore:

- Set up a Git repo and document your infrastructure
- Use SSH keys on all hosts and turn off password authentication for improved security
- Use [dockcheck.sh](https://github.com/mag37/dockcheck) to upgrade compose stacks automatically
- Set up uptime monitoring with [Uptime Kuma](https://github.com/louislam/uptime-kuma), hint: it also supports Pushover
- If you need more advanced monitoring, look into the [Prometheus](https://prometheus.io/docs/introduction/overview/) and [Grafana](https://grafana.com/) ecosystem
- Use Ansible to automate tasks like keeping hosts up to date
- Set up [Home Assistant](https://www.home-assistant.io/) and take back control of your smart home, with local-first management and control
- Set up a Proxmox Virtual Environment (PVE) server to run virtual machines and make better use of your hardware, and experiment with different operating systems or technologies
- Self-host your own router/firewall to remove the FRITZ!Box from your home network and unlock a more complex feature set. Depending on your internet connection, you will need, e.g., a DSL Modem like the DrayTek Vigor 166/167. You will also need a wireless access point to replicate the basic feature set of the FRITZ!Box.
- Set up Virtual LANs (VLANs) to segment your network into isolated partitions to increase security. For example, isolate your IoT devices from the rest of the network to prevent exploits affecting the rest of your infrastructure. You can also set up a Demilitarized Zone (DMZ) VLAN for services that are publicly accessible.
- Upgrade your network speed to 10 gigabit to increase the speed of file transfers and inter-server communication.
- Buy yourself an Uninterruptible Power Supply (UPS) to prevent servers from going offline and data loss during a power outage

# Hardware Recommendations

Regarding hardware, you hopefully gained some insights during the workshop that you don't need big, power-hungry servers to start self-hosting. You can get surprisingly far with very little. In the self-hosting community, there appear to be two schools of thought:

- Buy modern or low-power hardware for more money to save power and have a silent system
- Buy old enterprise hardware for cheap, with often more features and more expansion, but high power draw and noise

Personally, I'm mostly part of the latter group, but I had good success in keeping the noise levels down. As for the power draw, not so much. Power will be your primary expense in the long run when you want to self-host. There are many online tools available to calculate power consumption and cost based on your power draw and kWh price, e.g., see [here](https://www.wiwo.de/tools/stromkostenrechner/).

There also appears to be a split between people who buy hardware new (e.g., at Mindfactory, Amazon) and those who buy used (e.g., at eBay). I personally buy my hardware almost exclusively used or refurbished on eBay, and I have had practically no issues so far. Buying used can be like a superpower, as you can get great deals on enterprise equipment that surpasses the consumer counterpart in most categories, while being more affordable. Enterprise equipment does not necessarily have to be loud and power hungry. Consult datasheets and reports from others to make your decision!

When purchasing hardware, several key considerations and potential pitfalls should be taken into account. Below I will list some of them:

- You will most likely require more RAM than CPU power. On my primary Proxmox cluster at home, I'm using roughly 10GB of memory per virtual CPU / thread. While this involves a significant amount of overhead due to running VMs, you are likely fine with, e.g., 6 CPU cores and 32GB of RAM. Unless you have a large number of users, your services will typically remain idle for most of the time.

- While Mini-PCs can be a great starting point, they often lack expansion to add additional disks or PCIe devices. Embedded or Laptop CPUs typically have a limited number of PCIe lanes. If you need expansion to add a GPU or a Host Bus Adapter (HBA) to connect a backplane to your server, you will need to consider desktop, workstation, or enterprise-grade equipment.

- Intelligent Platform Management Interface (IPMI) can be a lifesaver and an incredible helper to manage your servers. It is effectively a small chip on the motherboard that is its own tiny computer, powering on as soon as the server receives power, independently of the main server itself. Typically, it can be accessed through a dedicated management Ethernet interface. You can access the chip via a web UI, where you can remotely turn on the server, view the display output in the browser, type commands, and even mount virtual ISO disks. Having IPMI eliminates the need for a KVM (an external device that connects to display output and USB to control the server over the network), but it does increase the power draw by a few watts.

- If you want to reduce your power draw, use desktop ATX power supplies, as they typically have a higher efficiency at lower power levels. In comparison, server-grade PSUs will often draw more power from the wall due to inefficiency. Having redundant power supplies increases the overhead further.

- If you want to upgrade your network speed, target 10 gigabit (10G) networking. It is mostly plug-and-play, and the power draw is still acceptable. As a consequence, some 10G switches can be passively cooled. Anything faster than 10G, such as 25G, 40G, and 100G, will become increasingly complex, costly, and power-hungry, and will suffer from incompatibilities between vendors. I recommend using Direct-Attach Copper (DAC) cables to connect your 10G devices, as DAC cables consume less power compared to using fiber optic transceiver modules. Their range is limited, but within the same rack, DACs should be the preferred cable type. They are also much cheaper than fiber and the respective transceivers.

- When buying HDDs and SSDs, pay attention to the interface. Most drives have either a SATA or SAS interface. You can use a SATA drive with a SAS controller, but not a SAS drive with a SATA controller. Most consumer hardware only supports SATA.

- When buying HDDs, pay attention to the recording technology: drives can be either SMR (Shingled Magnetic Recording) or CMR (Conventional Magnetic Recording). The former requires multiple sectors to be rewritten on a single write, as they are packed closer together, while the latter does not. Hence, CMR drives are **very much** recommended when building a BTRFS/ZFS RAID array.

- When setting up a Network Attached Storage (NAS) server or a storage server that holds data which might not be touched for years, it is essential to enable regular TRIM or scrub jobs to prevent bit-rot. This effectively means that the data on the drive gradually loses its readability, resulting in corrupted data blocks. A TRIM or scrub task periodically reads and writes data to keep it "fresh". NAS operating systems like [TrueNAS](https://www.truenas.com/) make it easy to configure TRIM tasks.

- When buying used SSDs, check if the seller lists the S.M.A.R.T. health values. They can indicate how much life a drive has left.

- When using ZFS, it is recommended to use Error Correction Code (ECC) memory, as it is capable of correcting errors in the memory contents. It's not a strict requirement, but it protects the integrity of your data.