/** E-mails de l'appli : textes en 6 langues + mise en page compatible Gmail, Outlook, Apple Mail. */

const T = {
  fr: {
    hello: 'Bonjour{name},',
    hi: (n) => (n ? ' ' + n : ''),
    codeValid: 'Ce code est valable 15 minutes et ne peut servir qu’une seule fois.',
    notYou: 'Ce n’était pas toi ? Ignore simplement ce message : rien ne sera modifié sur ton compte.',
    neverAsk: 'L’équipe Spot My Car ne te demandera jamais ce code. Ne le partage avec personne.',
    footer: 'Cet e-mail t’a été envoyé automatiquement par Spot My Car. Merci de ne pas y répondre.',
    support: 'Besoin d’aide ? Écris-nous depuis l’appli : Profil › Réglages › Contacter le support.',
    verify: { subject: '{code} est ton code Spot My Car', pre: 'Confirme ton adresse e-mail pour activer ton compte.', title: 'Confirme ton adresse e-mail', body: 'Bienvenue dans le garage ! Pour activer ton compte, saisis ce code dans l’appli :' },
    reset: { subject: '{code} : réinitialise ton mot de passe', pre: 'Ton code pour choisir un nouveau mot de passe.', title: 'Nouveau mot de passe', body: 'Tu as demandé à réinitialiser ton mot de passe. Saisis ce code dans l’appli pour en choisir un nouveau :' },
    resetDone: { subject: 'Ton mot de passe a été modifié', pre: 'Le mot de passe de ton compte vient d’être changé.', title: 'Mot de passe modifié', body: 'Le mot de passe de ton compte Spot My Car vient d’être changé. Tu peux te connecter avec ton nouveau mot de passe.', warn: 'Si tu n’es pas à l’origine de ce changement, contacte-nous immédiatement depuis l’appli.' },
    delete: { subject: '{code} : confirme la suppression de ton compte', pre: 'Code de confirmation pour supprimer ton compte.', title: 'Suppression du compte', body: 'Tu as demandé à supprimer ton compte Spot My Car. Cette action effacera définitivement ton garage, tes spots, tes photos et ta progression. Pour confirmer, saisis ce code :' },
    deleted: { subject: 'Ton compte Spot My Car a été supprimé', pre: 'Toutes tes données ont été effacées.', title: 'Compte supprimé', body: 'Ton compte et toutes tes données (garage, spots, photos, progression) ont été définitivement effacés. Merci d’avoir fait partie de l’aventure.', cta: 'Tu pourras toujours revenir : un nouveau garage t’attend quand tu veux.' },
    welcome: { subject: 'Bienvenue dans Spot My Car 🏁', pre: 'Ton compte est activé : à toi de spotter !', title: 'Ton garage est ouvert', body: 'Ton adresse est confirmée, ton compte est prêt. Voici comment bien démarrer :', steps: ['📸 Photographie une voiture dans la rue : l’IA reconnaît la marque et le modèle.', '🃏 Chaque spot devient une carte à collectionner, de Commune à Mythique.', '🏆 Gagne de l’XP, débloque des succès et monte de niveau.', '⚔️ Ajoute tes amis, lance des duels et des blind tests.'], end: 'Bonne chasse !' },
    supportAck: { subject: 'Nous avons bien reçu ton message', pre: 'Ticket {ticket} : on te répond au plus vite.', title: 'Message bien reçu', body: 'Merci pour ton message « {subject} ». Il est bien arrivé (ticket n° {ticket}). On te répond par e-mail au plus vite, en général sous 48 h.' },
    custom: { pre: 'Un message de l’équipe Spot My Car.' },
    team: 'L’équipe Spot My Car',
  },
  en: {
    hello: 'Hi{name},', hi: (n) => (n ? ' ' + n : ''),
    codeValid: 'This code is valid for 15 minutes and can only be used once.',
    notYou: 'Wasn’t you? Just ignore this email: nothing will change on your account.',
    neverAsk: 'The Spot My Car team will never ask you for this code. Don’t share it with anyone.',
    footer: 'This email was sent automatically by Spot My Car. Please do not reply.',
    support: 'Need help? Write to us from the app: Profile › Settings › Contact support.',
    verify: { subject: '{code} is your Spot My Car code', pre: 'Confirm your email address to activate your account.', title: 'Confirm your email', body: 'Welcome to the garage! To activate your account, enter this code in the app:' },
    reset: { subject: '{code}: reset your password', pre: 'Your code to choose a new password.', title: 'New password', body: 'You asked to reset your password. Enter this code in the app to choose a new one:' },
    resetDone: { subject: 'Your password was changed', pre: 'Your account password has just been changed.', title: 'Password changed', body: 'The password of your Spot My Car account has just been changed. You can now sign in with your new password.', warn: 'If you didn’t make this change, contact us right away from the app.' },
    delete: { subject: '{code}: confirm your account deletion', pre: 'Confirmation code to delete your account.', title: 'Delete account', body: 'You asked to delete your Spot My Car account. This will permanently erase your garage, spots, photos and progress. To confirm, enter this code:' },
    deleted: { subject: 'Your Spot My Car account was deleted', pre: 'All your data has been erased.', title: 'Account deleted', body: 'Your account and all your data (garage, spots, photos, progress) have been permanently erased. Thanks for being part of the ride.', cta: 'You can always come back: a new garage is waiting whenever you want.' },
    welcome: { subject: 'Welcome to Spot My Car 🏁', pre: 'Your account is active: time to spot!', title: 'Your garage is open', body: 'Your email is confirmed and your account is ready. Here’s how to get started:', steps: ['📸 Snap a car in the street: the AI recognises the make and model.', '🃏 Every spot becomes a collectible card, from Common to Mythic.', '🏆 Earn XP, unlock achievements and level up.', '⚔️ Add friends, start duels and blind tests.'], end: 'Happy hunting!' },
    supportAck: { subject: 'We received your message', pre: 'Ticket {ticket}: we’ll get back to you soon.', title: 'Message received', body: 'Thanks for your message “{subject}”. It reached us safely (ticket #{ticket}). We’ll reply by email as soon as possible, usually within 48 hours.' },
    custom: { pre: 'A message from the Spot My Car team.' },
    team: 'The Spot My Car team',
  },
  es: {
    hello: 'Hola{name}:', hi: (n) => (n ? ' ' + n : ''),
    codeValid: 'Este código es válido durante 15 minutos y solo puede usarse una vez.',
    notYou: '¿No has sido tú? Ignora este mensaje: no se cambiará nada en tu cuenta.',
    neverAsk: 'El equipo de Spot My Car nunca te pedirá este código. No lo compartas con nadie.',
    footer: 'Este correo lo ha enviado automáticamente Spot My Car. Por favor, no respondas.',
    support: '¿Necesitas ayuda? Escríbenos desde la app: Perfil › Ajustes › Contactar con soporte.',
    verify: { subject: '{code} es tu código de Spot My Car', pre: 'Confirma tu correo para activar tu cuenta.', title: 'Confirma tu correo', body: '¡Bienvenido al garaje! Para activar tu cuenta, introduce este código en la app:' },
    reset: { subject: '{code}: restablece tu contraseña', pre: 'Tu código para elegir una nueva contraseña.', title: 'Nueva contraseña', body: 'Has pedido restablecer tu contraseña. Introduce este código en la app para elegir una nueva:' },
    resetDone: { subject: 'Tu contraseña ha cambiado', pre: 'La contraseña de tu cuenta acaba de cambiar.', title: 'Contraseña cambiada', body: 'La contraseña de tu cuenta de Spot My Car acaba de cambiar. Ya puedes iniciar sesión con la nueva.', warn: 'Si no has sido tú, contáctanos de inmediato desde la app.' },
    delete: { subject: '{code}: confirma la eliminación de tu cuenta', pre: 'Código para eliminar tu cuenta.', title: 'Eliminar cuenta', body: 'Has pedido eliminar tu cuenta de Spot My Car. Se borrarán para siempre tu garaje, tus spots, tus fotos y tu progreso. Para confirmar, introduce este código:' },
    deleted: { subject: 'Tu cuenta de Spot My Car ha sido eliminada', pre: 'Todos tus datos se han borrado.', title: 'Cuenta eliminada', body: 'Tu cuenta y todos tus datos (garaje, spots, fotos, progreso) se han borrado definitivamente. Gracias por formar parte de la aventura.', cta: 'Puedes volver cuando quieras: un garaje nuevo te espera.' },
    welcome: { subject: 'Bienvenido a Spot My Car 🏁', pre: 'Tu cuenta está activa: ¡a spotear!', title: 'Tu garaje está abierto', body: 'Tu correo está confirmado y tu cuenta lista. Así se empieza:', steps: ['📸 Fotografía un coche en la calle: la IA reconoce marca y modelo.', '🃏 Cada spot se convierte en una carta coleccionable, de Común a Mítica.', '🏆 Gana XP, desbloquea logros y sube de nivel.', '⚔️ Añade amigos, lanza duelos y blind tests.'], end: '¡Buena caza!' },
    supportAck: { subject: 'Hemos recibido tu mensaje', pre: 'Ticket {ticket}: te respondemos pronto.', title: 'Mensaje recibido', body: 'Gracias por tu mensaje «{subject}». Nos ha llegado bien (ticket n.º {ticket}). Te responderemos por correo lo antes posible, normalmente en 48 h.' },
    custom: { pre: 'Un mensaje del equipo de Spot My Car.' },
    team: 'El equipo de Spot My Car',
  },
  de: {
    hello: 'Hallo{name},', hi: (n) => (n ? ' ' + n : ''),
    codeValid: 'Dieser Code ist 15 Minuten gültig und kann nur einmal verwendet werden.',
    notYou: 'Das warst nicht du? Ignoriere diese E-Mail einfach: An deinem Konto ändert sich nichts.',
    neverAsk: 'Das Spot-My-Car-Team wird dich niemals nach diesem Code fragen. Teile ihn mit niemandem.',
    footer: 'Diese E-Mail wurde automatisch von Spot My Car versendet. Bitte antworte nicht darauf.',
    support: 'Brauchst du Hilfe? Schreib uns in der App: Profil › Einstellungen › Support kontaktieren.',
    verify: { subject: '{code} ist dein Spot-My-Car-Code', pre: 'Bestätige deine E-Mail-Adresse, um dein Konto zu aktivieren.', title: 'Bestätige deine E-Mail', body: 'Willkommen in der Garage! Gib diesen Code in der App ein, um dein Konto zu aktivieren:' },
    reset: { subject: '{code}: Passwort zurücksetzen', pre: 'Dein Code für ein neues Passwort.', title: 'Neues Passwort', body: 'Du möchtest dein Passwort zurücksetzen. Gib diesen Code in der App ein, um ein neues zu wählen:' },
    resetDone: { subject: 'Dein Passwort wurde geändert', pre: 'Das Passwort deines Kontos wurde gerade geändert.', title: 'Passwort geändert', body: 'Das Passwort deines Spot-My-Car-Kontos wurde gerade geändert. Du kannst dich jetzt mit dem neuen Passwort anmelden.', warn: 'Warst du das nicht? Kontaktiere uns sofort über die App.' },
    delete: { subject: '{code}: Kontolöschung bestätigen', pre: 'Bestätigungscode zum Löschen deines Kontos.', title: 'Konto löschen', body: 'Du möchtest dein Spot-My-Car-Konto löschen. Deine Garage, Spots, Fotos und dein Fortschritt werden endgültig gelöscht. Gib zur Bestätigung diesen Code ein:' },
    deleted: { subject: 'Dein Spot-My-Car-Konto wurde gelöscht', pre: 'Alle deine Daten wurden gelöscht.', title: 'Konto gelöscht', body: 'Dein Konto und alle deine Daten (Garage, Spots, Fotos, Fortschritt) wurden endgültig gelöscht. Danke, dass du dabei warst.', cta: 'Du kannst jederzeit zurückkommen: Eine neue Garage wartet auf dich.' },
    welcome: { subject: 'Willkommen bei Spot My Car 🏁', pre: 'Dein Konto ist aktiv: Los geht’s!', title: 'Deine Garage ist geöffnet', body: 'Deine E-Mail ist bestätigt und dein Konto ist bereit. So startest du:', steps: ['📸 Fotografiere ein Auto auf der Straße: Die KI erkennt Marke und Modell.', '🃏 Jeder Spot wird zur Sammelkarte, von Gewöhnlich bis Mythisch.', '🏆 Sammle XP, schalte Erfolge frei und steige im Level auf.', '⚔️ Füge Freunde hinzu, starte Duelle und Blind-Tests.'], end: 'Viel Spaß beim Spotten!' },
    supportAck: { subject: 'Wir haben deine Nachricht erhalten', pre: 'Ticket {ticket}: Wir antworten bald.', title: 'Nachricht erhalten', body: 'Danke für deine Nachricht „{subject}“. Sie ist bei uns angekommen (Ticket Nr. {ticket}). Wir antworten so schnell wie möglich per E-Mail, meist innerhalb von 48 Stunden.' },
    custom: { pre: 'Eine Nachricht vom Spot-My-Car-Team.' },
    team: 'Dein Spot-My-Car-Team',
  },
  it: {
    hello: 'Ciao{name},', hi: (n) => (n ? ' ' + n : ''),
    codeValid: 'Questo codice è valido per 15 minuti e può essere usato una sola volta.',
    notYou: 'Non sei stato tu? Ignora questa email: sul tuo account non cambierà nulla.',
    neverAsk: 'Il team di Spot My Car non ti chiederà mai questo codice. Non condividerlo con nessuno.',
    footer: 'Questa email è stata inviata automaticamente da Spot My Car. Non rispondere.',
    support: 'Serve aiuto? Scrivici dall’app: Profilo › Impostazioni › Contatta il supporto.',
    verify: { subject: '{code} è il tuo codice Spot My Car', pre: 'Conferma il tuo indirizzo email per attivare l’account.', title: 'Conferma la tua email', body: 'Benvenuto in garage! Per attivare l’account, inserisci questo codice nell’app:' },
    reset: { subject: '{code}: reimposta la password', pre: 'Il tuo codice per scegliere una nuova password.', title: 'Nuova password', body: 'Hai chiesto di reimpostare la password. Inserisci questo codice nell’app per sceglierne una nuova:' },
    resetDone: { subject: 'La tua password è stata modificata', pre: 'La password del tuo account è appena cambiata.', title: 'Password modificata', body: 'La password del tuo account Spot My Car è appena stata cambiata. Ora puoi accedere con la nuova password.', warn: 'Se non sei stato tu, contattaci subito dall’app.' },
    delete: { subject: '{code}: conferma l’eliminazione dell’account', pre: 'Codice di conferma per eliminare l’account.', title: 'Elimina account', body: 'Hai chiesto di eliminare il tuo account Spot My Car. Garage, spot, foto e progressi verranno cancellati per sempre. Per confermare, inserisci questo codice:' },
    deleted: { subject: 'Il tuo account Spot My Car è stato eliminato', pre: 'Tutti i tuoi dati sono stati cancellati.', title: 'Account eliminato', body: 'Il tuo account e tutti i tuoi dati (garage, spot, foto, progressi) sono stati cancellati definitivamente. Grazie per aver fatto parte dell’avventura.', cta: 'Puoi tornare quando vuoi: un nuovo garage ti aspetta.' },
    welcome: { subject: 'Benvenuto su Spot My Car 🏁', pre: 'Il tuo account è attivo: inizia a spottare!', title: 'Il tuo garage è aperto', body: 'Email confermata, account pronto. Ecco come iniziare:', steps: ['📸 Fotografa un’auto per strada: l’IA riconosce marca e modello.', '🃏 Ogni spot diventa una carta da collezione, da Comune a Mitica.', '🏆 Guadagna XP, sblocca obiettivi e sali di livello.', '⚔️ Aggiungi amici, lancia duelli e blind test.'], end: 'Buona caccia!' },
    supportAck: { subject: 'Abbiamo ricevuto il tuo messaggio', pre: 'Ticket {ticket}: ti rispondiamo presto.', title: 'Messaggio ricevuto', body: 'Grazie per il messaggio «{subject}». È arrivato (ticket n. {ticket}). Ti risponderemo via email il prima possibile, di solito entro 48 ore.' },
    custom: { pre: 'Un messaggio dal team di Spot My Car.' },
    team: 'Il team di Spot My Car',
  },
  pt: {
    hello: 'Olá{name},', hi: (n) => (n ? ' ' + n : ''),
    codeValid: 'Este código é válido por 15 minutos e só pode ser usado uma vez.',
    notYou: 'Não foste tu? Ignora este e-mail: nada será alterado na tua conta.',
    neverAsk: 'A equipa Spot My Car nunca te pedirá este código. Não o partilhes com ninguém.',
    footer: 'Este e-mail foi enviado automaticamente pela Spot My Car. Por favor, não respondas.',
    support: 'Precisas de ajuda? Escreve-nos na app: Perfil › Definições › Contactar o suporte.',
    verify: { subject: '{code} é o teu código Spot My Car', pre: 'Confirma o teu e-mail para ativar a conta.', title: 'Confirma o teu e-mail', body: 'Bem-vindo à garagem! Para ativar a conta, introduz este código na app:' },
    reset: { subject: '{code}: redefine a tua palavra-passe', pre: 'O teu código para escolher uma nova palavra-passe.', title: 'Nova palavra-passe', body: 'Pediste para redefinir a palavra-passe. Introduz este código na app para escolher uma nova:' },
    resetDone: { subject: 'A tua palavra-passe foi alterada', pre: 'A palavra-passe da tua conta acabou de ser alterada.', title: 'Palavra-passe alterada', body: 'A palavra-passe da tua conta Spot My Car acabou de ser alterada. Já podes entrar com a nova.', warn: 'Se não foste tu, contacta-nos imediatamente pela app.' },
    delete: { subject: '{code}: confirma a eliminação da conta', pre: 'Código de confirmação para eliminar a conta.', title: 'Eliminar conta', body: 'Pediste para eliminar a tua conta Spot My Car. A garagem, os spots, as fotos e o progresso serão apagados para sempre. Para confirmar, introduz este código:' },
    deleted: { subject: 'A tua conta Spot My Car foi eliminada', pre: 'Todos os teus dados foram apagados.', title: 'Conta eliminada', body: 'A tua conta e todos os teus dados (garagem, spots, fotos, progresso) foram apagados definitivamente. Obrigado por fazeres parte da aventura.', cta: 'Podes voltar quando quiseres: uma nova garagem espera por ti.' },
    welcome: { subject: 'Bem-vindo à Spot My Car 🏁', pre: 'A tua conta está ativa: bora spotar!', title: 'A tua garagem está aberta', body: 'E-mail confirmado, conta pronta. Começa assim:', steps: ['📸 Fotografa um carro na rua: a IA reconhece a marca e o modelo.', '🃏 Cada spot torna-se uma carta colecionável, de Comum a Mítica.', '🏆 Ganha XP, desbloqueia conquistas e sobe de nível.', '⚔️ Adiciona amigos, lança duelos e blind tests.'], end: 'Boa caça!' },
    supportAck: { subject: 'Recebemos a tua mensagem', pre: 'Ticket {ticket}: respondemos em breve.', title: 'Mensagem recebida', body: 'Obrigado pela mensagem «{subject}». Chegou bem (ticket n.º {ticket}). Respondemos por e-mail o mais depressa possível, normalmente em 48 h.' },
    custom: { pre: 'Uma mensagem da equipa Spot My Car.' },
    team: 'A equipa Spot My Car',
  },
};

const C = {
  red: '#E5202E', ink: '#121216', soft: '#5A5A66', muted: '#8D8D98', line: '#E6E6EC', bg: '#F1F1F5', dark: '#0A0A0D', green: '#1FA463', amber: '#B26A00',
};

function esc_(s) {
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
function fill_(s, vars) {
  return String(s).replace(/\{(\w+)\}/g, (m, k) => (vars && vars[k] != null ? vars[k] : m));
}

function sendMail_(to, kind, lang, vars) {
  const t = T[lang] || T.en;
  const k = t[kind] || {};
  vars = vars || {};
  const subject = kind === 'custom' ? vars.subject : fill_(k.subject, { code: vars.code, subject: vars.subject, ticket: vars.ticket });
  const html = renderMail_(kind, t, k, vars);
  MailApp.sendEmail({
    to: to,
    subject: subject,
    htmlBody: html,
    body: plain_(kind, t, k, vars),
    name: APP_NAME,
    replyTo: 'noreply.spotmycar@gmail.com',
    inlineImages: { logo: logoBlob_() },
  });
}

function logoBlob_() {
  return Utilities.newBlob(Utilities.base64Decode(LOGO_PNG_B64), 'image/png', 'logo.png');
}

function plain_(kind, t, k, v) {
  const lines = [fill_(t.hello, { name: t.hi(v.name) }), ''];
  if (kind === 'custom') lines.push(v.message);
  else lines.push(fill_(k.body, v));
  if (v.code) lines.push('', '    ' + v.code, '', t.codeValid, t.notYou);
  lines.push('', t.team, '', t.footer);
  return lines.join('\n');
}

function codeBlock_(code) {
  const digits = String(code).split('').map((d) =>
    '<td style="padding:0 3px;"><div style="width:46px;height:58px;line-height:58px;border-radius:12px;background:#F4F4F7;border:1px solid ' + C.line +
    ';font-family:\'SF Mono\',Menlo,Consolas,\'Courier New\',monospace;font-size:30px;font-weight:800;color:' + C.ink + ';text-align:center;">' + d + '</div></td>'
  ).join('');
  return '<table role="presentation" cellpadding="0" cellspacing="0" align="center" style="margin:26px auto 10px;"><tr>' + digits + '</tr></table>';
}

function renderMail_(kind, t, k, v) {
  const greet = esc_(fill_(t.hello, { name: t.hi(v.name ? esc_(v.name) : '') }));
  let title = esc_(k.title || '');
  let body = '';
  let accent = C.red;
  let icon = '';
  if (kind === 'custom') {
    title = esc_(v.subject);
    body = '<p style="margin:0 0 14px;">' + greet + '</p>' + esc_(v.message).replace(/\n{2,}/g, '</p><p style="margin:0 0 14px;">').replace(/\n/g, '<br>');
    body = '<p style="margin:0 0 14px;">' + body + '</p><p style="margin:22px 0 0;color:' + C.soft + ';">— ' + esc_(t.team) + '</p>';
  } else {
    body = '<p style="margin:0 0 14px;">' + greet + '</p><p style="margin:0;">' + esc_(fill_(k.body, { subject: v.subject, ticket: v.ticket })) + '</p>';
  }
  if (kind === 'delete' || kind === 'deleted') accent = C.dark;
  if (kind === 'resetDone') icon = '🔒';
  if (kind === 'verify') icon = '✉️';
  if (kind === 'reset') icon = '🔑';
  if (kind === 'delete') icon = '⚠️';
  if (kind === 'deleted') icon = '👋';
  if (kind === 'welcome') icon = '🏁';
  if (kind === 'supportAck') icon = '💬';

  let extra = '';
  if (v.code) {
    extra += codeBlock_(v.code);
    extra += '<p style="margin:0;text-align:center;font-size:13px;color:' + C.muted + ';">' + esc_(t.codeValid) + '</p>';
  }
  if (kind === 'welcome' && k.steps) {
    extra += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:22px 0 6px;">' +
      k.steps.map((s) => '<tr><td style="padding:10px 14px;border-radius:12px;background:#F6F6F9;font-size:15px;line-height:1.45;color:' + C.ink + ';">' + esc_(s) + '</td></tr><tr><td style="height:8px;"></td></tr>').join('') +
      '</table><p style="margin:14px 0 0;font-weight:700;">' + esc_(k.end) + '</p>';
  }
  if (kind === 'deleted' && k.cta) extra += '<p style="margin:18px 0 0;color:' + C.soft + ';">' + esc_(k.cta) + '</p>';
  if (kind === 'resetDone' && k.warn) {
    extra += '<div style="margin:22px 0 0;padding:14px 16px;border-radius:12px;background:#FFF6E5;border:1px solid #F5D9A3;color:' + C.amber + ';font-size:14px;">' + esc_(k.warn) + '</div>';
  }
  let security = '';
  if (v.code) {
    security = '<tr><td style="padding:0 36px 30px;"><div style="padding:14px 16px;border-radius:12px;background:#F6F6F9;font-size:13px;line-height:1.5;color:' + C.soft + ';">' +
      '🛡️ ' + esc_(t.neverAsk) + '<br>' + esc_(t.notYou) + '</div></td></tr>';
  }
  const pre = esc_(kind === 'custom' ? k.pre : fill_(k.pre || '', { ticket: v.ticket }));

  return '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<meta name="color-scheme" content="light only"><meta name="supported-color-schemes" content="light only"><title>' + title + '</title></head>' +
    '<body style="margin:0;padding:0;background:' + C.bg + ';-webkit-text-size-adjust:100%;">' +
    '<div style="display:none;max-height:0;overflow:hidden;opacity:0;">' + pre + '</div>' +
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:' + C.bg + ';"><tr><td align="center" style="padding:28px 12px;">' +
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,Helvetica,Arial,sans-serif;">' +
    // en-tête
    '<tr><td style="background:' + C.dark + ';border-radius:22px 22px 0 0;padding:26px 30px;">' +
    '<table role="presentation" cellpadding="0" cellspacing="0"><tr>' +
    '<td style="vertical-align:middle;"><img src="cid:logo" width="44" height="44" alt="Spot My Car" style="display:block;border-radius:11px;"></td>' +
    '<td style="vertical-align:middle;padding-left:12px;"><div style="font-family:\'Barlow Condensed\',\'Arial Narrow\',Arial,sans-serif;font-size:22px;font-weight:800;letter-spacing:1.5px;color:#FFFFFF;">SPOT <span style="color:' + C.red + ';">MY</span> CAR</div>' +
    '<div style="font-size:10px;letter-spacing:2.5px;color:#9A9AA6;font-weight:700;margin-top:2px;">LE CARSPOTTING, EN COLLECTION</div></td>' +
    '</tr></table></td></tr>' +
    '<tr><td style="height:4px;background:' + accent + ';background-image:linear-gradient(90deg,' + C.red + ',#FF7A1A);line-height:4px;font-size:0;">&nbsp;</td></tr>' +
    // contenu
    '<tr><td style="background:#FFFFFF;padding:34px 36px 26px;font-size:16px;line-height:1.55;color:' + C.ink + ';">' +
    (icon ? '<div style="font-size:30px;line-height:1;margin-bottom:12px;">' + icon + '</div>' : '') +
    '<h1 style="margin:0 0 18px;font-size:25px;line-height:1.2;font-weight:800;color:' + C.ink + ';">' + title + '</h1>' +
    body + extra +
    '</td></tr>' +
    (security ? security.replace('<tr><td style="padding:0 36px 30px;">', '<tr><td style="background:#FFFFFF;padding:0 36px 30px;">') : '') +
    '<tr><td style="background:#FFFFFF;border-radius:0 0 22px 22px;padding:0 36px 30px;"><div style="border-top:1px solid ' + C.line + ';padding-top:18px;font-size:13px;color:' + C.soft + ';">' + esc_(t.team) + '</div></td></tr>' +
    // pied
    '<tr><td style="padding:22px 26px 6px;text-align:center;font-size:12px;line-height:1.6;color:' + C.muted + ';">' + esc_(t.support) + '<br>' + esc_(t.footer) +
    '<br><span style="color:#B4B4BE;">© ' + new Date().getFullYear() + ' Spot My Car</span></td></tr>' +
    '</table></td></tr></table></body></html>';
}

function supportInboxHtml_(topic, subject, message, from, rows, id) {
  const tr = rows.map((r) => '<tr><td style="padding:6px 10px;color:#5A5A66;white-space:nowrap;">' + esc_(r[0]) + '</td><td style="padding:6px 10px;">' + esc_(r[1]) + '</td></tr>').join('');
  return '<div style="font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;max-width:640px;margin:auto;color:#121216;">' +
    '<div style="background:#0A0A0D;color:#fff;padding:18px 22px;border-radius:16px 16px 0 0;font-weight:800;letter-spacing:1px;">SPOT <span style="color:#E5202E;">MY</span> CAR · SUPPORT</div>' +
    '<div style="background:#fff;border:1px solid #E6E6EC;border-top:none;border-radius:0 0 16px 16px;padding:22px;">' +
    '<div style="display:inline-block;background:#FDE7E9;color:#B0101C;font-weight:700;font-size:12px;padding:4px 10px;border-radius:99px;">' + esc_(topic) + '</div>' +
    '<h2 style="margin:12px 0 6px;">' + esc_(subject) + '</h2>' +
    '<div style="color:#5A5A66;font-size:13px;margin-bottom:16px;">De : ' + esc_(from || 'anonyme') + ' · Ticket ' + esc_(id.slice(0, 6).toUpperCase()) + '</div>' +
    '<div style="white-space:pre-wrap;font-size:15px;line-height:1.55;background:#F6F6F9;border-radius:12px;padding:14px 16px;">' + esc_(message) + '</div>' +
    '<table style="margin-top:16px;font-size:13px;border-collapse:collapse;">' + tr + '</table>' +
    '<p style="font-size:12px;color:#8D8D98;margin-top:18px;">Réponds directement à cet e-mail : la réponse part vers le joueur.</p>' +
    '</div></div>';
}
