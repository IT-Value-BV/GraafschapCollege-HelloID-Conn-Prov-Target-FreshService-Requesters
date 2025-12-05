
# Introductie
FreshService beschikt over een API waarmee het mogelijk is om automatische acties uit te voeren. Deze koppeling maakt gebruik van de API om aanvragers (requesters) automatisch te provisionen. 

---

## Doelsysteem
Deze repository bevat alles om te koppelen met het **FreshService** vanuit HelloID. Volg onderstaande stappen om de koppeling in te richten. 

> [!IMPORTANT]  
> Het Microsoft Active Directory Doelsysteem moet geconfigureerd zijn voordat FreshService gekoppeld kan worden

---

### **Voorbereidingen FreshService** 
*Om te kunnen verbinden met een FreshService omgeving moet er een API key aangemaakt worden*

> [!TIP]
> Onderstaande instructie beschrijft de stappen om gebruik te maken van de API onder de tenant eigenaar agent. Het is best-practice om hier een specifiek account voor aan te maken dat niet bedoeld is voor regulier gebruik. 

1. Ga naar het admin portaal van FreshService:
    `https://tenantnaam.freshservice.com/agents`
2. Log in met de eerste agent, de tenant eigenaar
2. Selecteer de agent waar je nu mee bent ingelogd
3. Schakel het gebruik van API keys in
[Assets/FreshService-Enable-API.png]
4. Navigeer naar de profiel instellingen van je account
[Assets/FreshService-Profile-Settings.png]
5. Kopieer de API key, deze heb je later nodig in HelloID
[FreshService API key](Assets/FreshService-API-Key.png)

---


### **Aanmaken doelsysteem**
1. Ga naar het HelloID Provisioning administrator portaal:  
   `https://gc-bedrijfsnaam.helloid.training/provisioning`
2. Navigeer naar **Target → Systems**  
3. Klik rechtsbovenin op het + icoon
4. Kies voor de eerste optie **PowerShell** en klik op **Create**

---

### **Inrichting doelsysteem**  
*Hier voeg je de benodigde scripts en configuratie toe.*  
1. Op het tabblad **General** kun je de naam wijzigen, bijvoorbeeld naar **FreshService | Requesters**  
2. Voeg het icoon van het doelsysteem toe:
   `https://raw.githubusercontent.com/IT-Value-BV/GraafschapCollege-HelloID-Conn-Prov-Target-FreshService-Requesters/refs/heads/main/icon.png`
3. Ga naar het tabblad **Account**  
4. Voeg voor de account acties de scripts toe uit deze GitHub repository:
   - `Create -> create.ps1`  
   - `Enable -> enable.ps1` 
   - `Update -> update.ps1` 
   - `Disable -> disable.ps1` 
   - `Delete -> enable.ps1`
5. Bewerk de **Custom connector configuration** en voeg hier de JSON code uit het bestand **configuration.json** toe
6. Voeg het Microsoft Active Directory doelsysteem toe onder **Use account data from systems**
7. Ga naar het tabblad **Fields**
8. Verwijder de huidige fieldmapping door op de knop **Delete all** te klikken
9. Klik op import en voeg het bestand **fieldMapping.json** toe
10. Bewerk de fieldmapping voor het veld **primary_email**
[HelloID Complex mapping](Assets/HelloID-Complex-Mapping.png)
11. Typ hier handmatig het variabele **Person.Accounts.MicrosoftActiveDirectory.mail**
12. Selecteer een persoon en klik op preview om te valideren dat het werkt, sla de configuratie op
13. Ga naar het tabblad **Configuration**
14. Vul de gegevens in van de FreshService omgeving en klik op **Apply**
[HelloID Configuration](Assets/HelloID-Configuration.png)
15. Ga naar het tabblad **Correlation**
16. Configureerd de correlatie als volgt:
[HelloID Correlation](Assets/HelloID-Correlation.png)

---

### **Testen connectie**  
*Hier controleer je of de koppeling werkt.*  
1. Ga naar het tabblad **Account**  
2. Open het **Account create** script
3. Selecteer een persoon en klik op **Preview**
4. Als alles goed ingericht is weergeeft de logging de onderstaande melding
[HelloID Preview](Assets/HelloID-Preview.png)

---

### **Configureren thresholds**  
*Thresholds voorkomen onverwachte acties als er een fout voorgekomen is in HelloID of een externe API.*  
Stel thresholds in op het tabblad **Thresholds**:  
[HelloID Thresholds](Assets/HelloID-Thresholds.png)

---

### **Bijwerken Business Rules**  
*Om geautomatiseerd acties uit tevoeren vanuit het nieuwe doelsysteem, moeten de Business Rules bijgwerkt worden.*  
1. Ga naar **Business → Rules**  
2. Open een bestaande rule of maak een nieuwe aan
3. Voeg de entitlements voor FreshService toe en publiceer deze
   - `Account`  
   - `Account Access` 
4. Om de configuratie actief te maken navigeer je naar **Business -> Evaluations**
5. Klik rechtsbovenin op **Enforce** om de acties uit te laten voeren

---

Vanaf nu heb je HelloID volledig geconfigureerd. Op basis van de brongegevens worden accounts aangemaakt in AD en FreshService. 