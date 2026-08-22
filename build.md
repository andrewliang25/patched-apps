Twitter/X-Piko: 12.7.1-release.0  

Install [MicroG-RE](https://github.com/MorpheApp/MicroG-RE/releases) for non-root Google APKs  
Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to detach patched apps from Play Store  

Repository: [Patched Apps](https://github.com/andrewliang25/patched-apps)  

Every APK/module is published with [GitHub build provenance attestations](https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds) — verify a downloaded file with the [GitHub CLI](https://cli.github.com):  
```  
gh attestation verify <file> --repo andrewliang25/patched-apps  
```  
Patches: crimera/patches-3.8.0.mpp  
[Changelog](https://github.com/crimera/piko/releases/tag/v3.8.0)

CLI: MorpheApp/morphe-desktop-1.13.1-all.jar    
