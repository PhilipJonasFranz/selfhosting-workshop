# 1 - Introduction

Welcome to the self-hosting workshop! In the workshop, we'll explore how to take control of your own digital services by self-hosting them, rather than relying on cloud services.

You'll learn the fundamentals of how to deploy services from within your home network with Docker, how to obtain SSL certificates, how to secure them with Authentication, and how to expose or access them if you are not home. We will also discuss other topics, such as backups.

The goal of this workshop is for you to become comfortable with self-hosting on your own infrastructure and to take that knowledge home to start your self-hosting journey.

Before starting, fill in the `.workshop.env` file with your values and run `python3 replace.py` to template all configurations to your needs. You might need to install the `dotenv` Python library.

# Why should I self-host?

Self-hosting means being in control of your data and services. In previous years, I have seen many examples of "enshittification", or the process of making a product worse for the users with the incentive to increase profits:

- [Microsoft OneDrive: Facial Recognition is opt-out, and can only be turned off three times per year](https://www.pcgamer.com/software/ai/preview-users-have-noticed-onedrives-ai-driven-face-recognition-setting-is-opt-out-and-can-only-be-turned-off-three-times-a-year/)
- [Prime Video introduces ads to paid subscriptions](https://convergence-now.com/broadcast-digital-media/amazon-prime-video-introduces-in-show-ads-with-optional-paid-ad-free-plan-119343/)
- [TeamViewer terminates perpetual license, offers subscription instead](https://linustechtips.com/topic/1614802-teamviewer-is-terminating-my-perpetual-license-%E2%80%94-has-this-happened-to-anyone-else-what-are-you-doing-about-this/)

Enshittification often reduces the quality of the user experience, sells user data, introduces ads into paid subscriptions, or discontinues a service entirely. Self-hosting and running open-source software means you are in control, and you decide whether to update, modify, or discontinue the services you use. And if you'd like, you can still support the projects you use by donating to them.

Self-hosting also helps increase the resilience of the Internet by decentralizing services and distributing data to users, rather than storing everything in the Cloud, which is essentially just someone else's computer. The more centralized the infrastructure is, the bigger the impact will be in the case of an outage. Typical examples are outages at major cloud providers like AWS, Azure, or GCP:

- [AWS Outage causes Smart Beds to overheat and get stuck in upright position](https://www.upi.com/Odd_News/2025/10/22/Eight-Sleep-smart-beds-Amazon-Web-Services-outage/3431761144108/)

# Are there things I should not self-host?

Being in control can both be a good thing and a bad thing, as it places the responsibility in your hands. Some things are more challenging to self-host than others, but there are some services that I would not recommend beginners to self-host. These include:

- Email / Email Servers
- Password Managers

Apart from the security aspect, these services are your lifeline when everything goes sideways. I thus cannot recommend them unless you are very familiar with self-hosting and have a plan to recover from a worst-case scenario.

# What do I need to self-host?

To self-host, you need:

- a server to run your apps
- (somewhat) reliable storage
- networking in some shape or form
- a software stack
- power

For a basic home server, almost anything will do - for example, a Raspberry Pi, an old Desktop PC, or a mini-PC. You can find old, used hardware for relatively cheap on eBay. Personally, I would recommend devices like the Dell OptiPlex line or devices from the [Tiny, Mini, Micro](https://www.servethehome.com/introducing-project-tinyminimicro-home-lab-revolution/) line. These devices are practically silent, are pretty efficient, and offer much more performance in comparison to RPis, especially when considering their price. Additionally, they are x86-based, which is an advantage, as many services are not available for the ARM architecture that RPis use. The desktop variant of the OptiPlex series can also be attractive and a great starting point, as it offers more expansion than a micro form-factor device.

For storage, you can either use SSDs for more speed at the cost of capacity, or use slower HDDs (spinning rust) for larger storage needs. Of course, a mix of the two can also be a good choice. I generally recommend using SSDs unless you need more storage, as they can last longer than HDDs, have lower power consumption, and offer higher speeds. You can also buy them used with more confidence that they will not immediately break.

Regarding networking, anything Gigabit is fine. 10 gigabit (10G) networking is fairly accessible today, but it is not typically needed in most self-hosting scenarios. Most of the time, your services will sit idle, requiring little or no bandwidth. For Gigabit Ethernet, RJ-45 cables are generally suitable. For 10G networking, I recommend using DACs for power efficiency and cost reasons.

When choosing your software stack, there is no right or wrong (mostly). The most obvious choice is to use a flavor of Linux; however, using Windows can also be a valid option. I choose free and open-source software if possible, as this leaves you with the highest amount of control and transparency over what is actually running on your devices. You can run your services either bare metal, as containers, or use Virtual Machines (VMs). This mostly comes down to preference. Running services natively is the most performant, but requires the highest amount of effort to manage. Containerization, for example with Docker, only marginally decreases performance, but can drastically simplify management. Running services in VMs is the least performant option, but it offers the highest degree of flexibility and makes management and administration tasks, such as backups, very easy. We will be choosing Docker for this workshop as it is a beginner-friendly middle ground and a great option for most situations.

Finally, you need to power your infrastructure. And don't worry, you can get very far with very little power. If you are interested in determining the power consumption of a small PC or switch, you can use a small power measurement device like a Shelly Plug to measure the power consumption, and calculate your monthly power cost using a website like [this](https://www.wiwo.de/tools/stromkostenrechner/).

# What is a homelab, and do I need one?

A homelab is a place you can experiment, learn, and fail in the privacy of your own home. It relieves the pressure of working in a production environment and allows you to expand your skillset at your own pace. Homelabs come in all shapes and sizes, ranging from a single Raspberry Pi to a miniature data center.

A homelab is a sandboxed environment where you can experiment with self-hosting, networking, automation, or virtualization, without risking downtime in production systems.

Typical homelabbing projects could be:

- Hosting personal services (Nextcloud, media servers, etc.)
- Learning and testing technologies like Docker, Kubernetes, or Ansible
- Experimenting with networking setups (VLANs, VPNs, firewalls)
- Creating backup and monitoring systems

You don't need a homelab to self-host. Ideally, a homelab is separate from your production self-hosted services to prevent mishaps or data loss while experimenting. In practice, the two concepts do overlap quite a bit, and sharing infrastructure can work reasonably well.