class DialogflowService {
  static String getResponse(String input) {
    input = input.toLowerCase();

    // Domestic Violence
    if (input.contains('domestic') ||
        input.contains('husband') ||
        input.contains('wife') ||
        input.contains('spouse') ||
        input.contains('pwdva')) {
      return '⚖️ Under the Protection of Women from Domestic Violence Act (PWDVA) 2005:\n\n'
          '✅ You have the right to:\n'
          '• Live in your shared household\n'
          '• Get a Protection Order from court\n'
          '• Claim monetary relief\n\n'
          '📋 Steps to take:\n'
          '1. Contact a Protection Officer\n'
          '2. File complaint at nearest police station\n'
          '3. Approach a Magistrate court\n\n'
          '📞 Helpline: 181 (Women Helpline)\n'
          '📞 Police: 100';
    }

    // Sexual Harassment / POSH
    else if (input.contains('harassment') ||
        input.contains('posh') ||
        input.contains('workplace') ||
        input.contains('eve teasing') ||
        input.contains('molest')) {
      return '⚖️ Sexual Harassment Laws in India:\n\n'
          '🏢 Workplace (POSH Act 2013):\n'
          '• Every workplace must have an Internal Complaints Committee (ICC)\n'
          '• File complaint with ICC within 3 months\n'
          '• Employer must act within 90 days\n\n'
          '🚶 Public Place (IPC Section 354):\n'
          '• Eve teasing is a criminal offence\n'
          '• File FIR at nearest police station\n\n'
          '📞 Helpline: 1091\n'
          '📞 NCW: 7827170170';
    }

    // POCSO
    else if (input.contains('pocso') ||
        input.contains('child') ||
        input.contains('minor') ||
        input.contains('abuse')) {
      return '⚖️ POCSO Act 2012 (Protection of Children from Sexual Offences):\n\n'
          '👶 Protects all children under 18 years\n\n'
          '📋 What to do:\n'
          '1. Call CHILDLINE: 1098 (free, 24/7)\n'
          '2. Report to nearest police station\n'
          '3. Medical examination must be done\n'
          '4. Identity of child must be protected\n\n'
          '⚠️ Reporting POCSO is mandatory by law\n\n'
          '📞 CHILDLINE: 1098\n'
          '📞 Police: 100';
    }

    // FIR Filing
    else if (input.contains('fir') ||
        input.contains('police') ||
        input.contains('complaint') ||
        input.contains('report')) {
      return '📋 How to File an FIR:\n\n'
          '1. Go to the nearest police station\n'
          '2. Meet the Station House Officer (SHO)\n'
          '3. Give your complaint in writing\n'
          '4. FIR must be registered — it\'s your right\n'
          '5. Get a FREE copy of the FIR\n\n'
          '⚠️ If police refuse to register FIR:\n'
          '• Send complaint by post to SP/DSP\n'
          '• File complaint at magistrate court\n'
          '• Call 100 or Women Helpline 1091\n\n'
          '📞 Police Control Room: 100\n'
          '📞 Women Helpline: 1091';
    }

    // Emergency / SOS
    else if (input.contains('danger') ||
        input.contains('emergency') ||
        input.contains('help') ||
        input.contains('sos') ||
        input.contains('scared') ||
        input.contains('attack')) {
      return '🚨 EMERGENCY — Get Help Now!\n\n'
          '📞 Call 112 (All Emergencies)\n'
          '📞 Call 1091 (Women Helpline)\n'
          '📞 Call 100 (Police)\n\n'
          '⚡ Use the SOS button on the home screen to alert your emergency contacts immediately!\n\n'
          'Stay in a public place if possible.\n'
          'Make noise to attract attention.\n'
          'Trust your instincts — leave if unsafe.';
    }

    // Stalking
    else if (input.contains('stalk') ||
        input.contains('follow') ||
        input.contains('threaten')) {
      return '⚖️ Stalking is a Criminal Offence (IPC Section 354D):\n\n'
          '• First offence: up to 3 years imprisonment\n'
          '• Repeat offence: up to 5 years imprisonment\n\n'
          '📋 Steps to take:\n'
          '1. Document all incidents with dates/times\n'
          '2. Save all messages/evidence\n'
          '3. File FIR at nearest police station\n'
          '4. Apply for restraining order\n\n'
          '📞 Women Helpline: 1091\n'
          '📞 Cyber Crime (online stalking): 1930';
    }

    // Cyber Crime
    else if (input.contains('cyber') ||
        input.contains('online') ||
        input.contains('photo') ||
        input.contains('morphed') ||
        input.contains('blackmail')) {
      return '⚖️ Cyber Crime Against Women (IT Act 2000):\n\n'
          '🔒 Offences covered:\n'
          '• Morphed/obscene images\n'
          '• Online harassment\n'
          '• Blackmail/extortion\n'
          '• Cyberstalking\n\n'
          '📋 Steps:\n'
          '1. Take screenshots as evidence\n'
          '2. Report at cybercrime.gov.in\n'
          '3. Call cyber helpline: 1930\n'
          '4. File FIR at cyber crime cell\n\n'
          '📞 Cyber Helpline: 1930\n'
          '🌐 cybercrime.gov.in';
    }

    // Default
    else {
      return 'I\'m here to help with legal guidance. Please ask me about:\n\n'
          '• 🏠 Domestic Violence\n'
          '• 👩 Sexual Harassment / POSH Act\n'
          '• 👶 POCSO Act (Child Protection)\n'
          '• 📋 FIR Filing Procedure\n'
          '• 👁️ Stalking Laws\n'
          '• 💻 Cyber Crime\n'
          '• 🚨 Emergency Help\n\n'
          'Type any of these topics or describe your situation.';
    }
  }
}
