// Real member roster. Imported by index.ts.
// Phone format: any (will be normalized to 9 digits).
// committees: list of { name_en, role } where role is 'head'|'vice_head'|'member'.
// club_role: optional president-equivalent role.

export type SeedMember = {
  full_name: string;
  phone: string;
  university_id: string;
  email?: string;
  committees: { name_en: string; role: 'head' | 'vice_head' | 'member' }[];
  club_role?:
    | 'president'
    | 'vice_president'
    | 'board_member'
    | 'club_leader'
    | 'club_vice_leader'
    | 'app_admin';
};

const HR = 'Human Resources';
const PM = 'Project Management';
const PR = 'Public Relations';
const QD = 'Quality & Development';
const GD = 'Guidance';
const AM = 'Activity Management';
const TE = 'Technology';
const ME = 'Media';

export const BOARD: SeedMember[] = [
  { full_name: 'محمد الشتوي', phone: '554144761', university_id: '442103121', email: 'Tttalbr@gmail.com', committees: [], club_role: 'board_member' },
  { full_name: 'محمد الجنيدل', phone: '553386412', university_id: '442101381', email: 'mohammedaljonaidel@gmail.com', committees: [], club_role: 'board_member' },
  { full_name: 'أماسي الدوسري', phone: '593535168', university_id: '443200521', email: 'amasifawzan@gmail.com', committees: [], club_role: 'board_member' },
];

export const LEADERSHIP: SeedMember[] = [
  { full_name: 'سفانة الهديب', phone: '556577743', university_id: '443201974', email: 'sffan502@gmail.com', committees: [], club_role: 'club_leader' },
  { full_name: 'ريما العتيبي', phone: '551486791', university_id: '445203893', email: 'nnoo38951@gmail.com', committees: [], club_role: 'club_vice_leader' },
  { full_name: 'رائد باطرفي', phone: '532993382', university_id: '444102729', email: 'Raed.Batarfi@hotmail.com', committees: [], club_role: 'club_vice_leader' },
];

export const HEADS: SeedMember[] = [
  { full_name: 'عبدالعزيز الجنيدلي', phone: '500927474', university_id: '446104004', committees: [{ name_en: HR, role: 'head' }] },
  { full_name: 'ليان الحربي', phone: '563524620', university_id: '445201946', committees: [{ name_en: HR, role: 'vice_head' }] },
  { full_name: 'أحمد العبلاني', phone: '592706050', university_id: '443101921', committees: [{ name_en: PM, role: 'head' }] },
  { full_name: 'شهد السيف', phone: '553127179', university_id: '444201171', committees: [{ name_en: PM, role: 'vice_head' }] },
  { full_name: 'غلا آل سبيت', phone: '542467161', university_id: '445200772', committees: [{ name_en: PR, role: 'head' }] },
  { full_name: 'إبراهيم الفايز', phone: '535754989', university_id: '445102104', committees: [{ name_en: PR, role: 'vice_head' }] },
  { full_name: 'شعاع القحطاني', phone: '501596696', university_id: '444927013', committees: [{ name_en: PR, role: 'vice_head' }] },
  { full_name: 'ميلاف المشعلي', phone: '555311460', university_id: '446202812', committees: [{ name_en: QD, role: 'head' }] },
  { full_name: 'ديم الرشيد', phone: '504904065', university_id: '446205075', committees: [{ name_en: QD, role: 'vice_head' }] },
  { full_name: 'نور العيد', phone: '543443565', university_id: '446204832', committees: [{ name_en: GD, role: 'head' }] },
  { full_name: 'داليا الهويمل', phone: '557569290', university_id: '444202935', committees: [{ name_en: GD, role: 'vice_head' }] },
  { full_name: 'وعد معشي', phone: '558646708', university_id: '444202508', committees: [{ name_en: AM, role: 'head' }] },
  { full_name: 'عبدالله الدوسري', phone: '532041372', university_id: '446103784', committees: [{ name_en: AM, role: 'vice_head' }] },
  { full_name: 'جود الجارالله', phone: '502114084', university_id: '445203690', committees: [{ name_en: AM, role: 'vice_head' }] },
  { full_name: 'فجر العتيبي', phone: '552456281', university_id: '446008421', committees: [{ name_en: TE, role: 'head' }] },
  { full_name: 'أحمد الغامدي', phone: '549236929', university_id: '445102252', committees: [{ name_en: TE, role: 'vice_head' }] },
  { full_name: 'رنا بن دوخي', phone: '558964739', university_id: '444200725', committees: [{ name_en: ME, role: 'head' }] },
  { full_name: 'نواف بن راشد', phone: '552466362', university_id: '445107359', committees: [{ name_en: ME, role: 'vice_head' }] },
];

export const HR_MEMBERS: SeedMember[] = [
  { full_name: 'طرفة عبدالله الطويل', phone: '0557389186', university_id: '444202222', email: 'tarfah2444@gmail.com', committees: [{ name_en: HR, role: 'member' }] },
  { full_name: 'لينا عبدالله سعد بن حسين', phone: '0551681034', university_id: '446205926', email: 'Lina10@outlook.sa', committees: [{ name_en: HR, role: 'member' }] },
  { full_name: 'عهد علي اللحيدان', phone: '0505882270', university_id: '446205081', email: 'vahd1@icloud.com', committees: [{ name_en: HR, role: 'member' }] },
  { full_name: 'فاطمه عبدالرحمن الحجيري', phone: '0552122562', university_id: '444200559', email: 'fatmtalhjyry46@gmail.com', committees: [{ name_en: HR, role: 'member' }] },
  { full_name: 'سديم حمد التركي', phone: '0552705751', university_id: '446202940', committees: [{ name_en: HR, role: 'member' }] },
  { full_name: 'رفا عبدالله اليحياء', phone: '0551841428', university_id: '447205427', email: 'rafaalyahya.28@gmail.com', committees: [{ name_en: HR, role: 'member' }] },
  { full_name: 'جود موسى الهاجري', phone: '0547607064', university_id: '444204516', email: 'joodalhajri5@gmail.com', committees: [{ name_en: HR, role: 'member' }] },
  { full_name: 'ساره ابراهيم الضفيان', phone: '566445087', university_id: '446202676', committees: [{ name_en: HR, role: 'member' }] },
  { full_name: 'جود الغامدي', phone: '0501205880', university_id: '446207187', email: 'jjoodd9919@gmail.com', committees: [{ name_en: HR, role: 'member' }] },
  { full_name: 'نوره فيصل الحربي', phone: '500342715', university_id: '445201575', email: 'nv37ii@gmail.com', committees: [{ name_en: HR, role: 'member' }] },
  { full_name: 'خالد عمار الخالدي', phone: '0557376112', university_id: '444102818', email: 'Khaled72mails@gmail.com', committees: [{ name_en: HR, role: 'member' }] },
];

export const PM_MEMBERS: SeedMember[] = [
  { full_name: 'رنيم عايض الشهراني', phone: '966505136525', university_id: '443200487', email: 'raneem.a.alshahrani@gmail.com', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'ريم السبيعي', phone: '0504549148', university_id: '446205363', email: 'reemalsubaei7@icloud.com', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'أسيل يحي العتين', phone: '0540900419', university_id: '446201536', email: 'Otainaseel@gmail.com', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'نوره نواف العتيبي', phone: '0531173511', university_id: '444201244', email: 'Nouraalotaibin@gmail.com', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'سعود عبدالعزيز النزال', phone: '0531342124', university_id: '446100034', email: 'Saud.alnazzal090@gmail.com', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'روناء مجدي السيد', phone: '0540591715', university_id: '447205724', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'شادن دخيل المسعود', phone: '0552469910', university_id: '444200857', email: 'Shaden.dakheel.11@gmail.com', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'جود معيش الحارثي', phone: '0553811032', university_id: '445202474', email: 'Joudalharthi01@gmail.com', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'دارين عبدالله الحارثي', phone: '0566956836', university_id: '447201850', email: 'dareen.alharthi2@gmail.com', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'هيا بدر الواصل', phone: '0582137304', university_id: '444926931', email: 'hybader.9@gmail.com', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'حلا محمد علي', phone: '0505981344', university_id: '447205762', email: 'Halahabed97@gmail.com', committees: [{ name_en: PM, role: 'member' }] },
  { full_name: 'منيرة حمد ال قاسم', phone: '0540472904', university_id: '445201704', committees: [{ name_en: PM, role: 'member' }] },
];

export const PR_MEMBERS: SeedMember[] = [
  { full_name: 'حسن يحيى ال خالص', phone: '0530553131', university_id: '445100050', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'تاله هاني الحارثي', phone: '0500265564', university_id: '446206103', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'سديم سعود أبابطين', phone: '0554633900', university_id: '447202813', email: 'sadeemsma07@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'انيسه صالح الرحيمي', phone: '0536215813', university_id: '444202580', email: 'Anisah.34534@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'نوره عبدالكريم الدواس', phone: '0591101402', university_id: '446202607', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'أرياف عبدالله القحطاني', phone: '0530634775', university_id: '222415918', email: 'iiout865t@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'نوف مرزوق العتيبي', phone: '0554850895', university_id: '445928504', email: 'noufotb83@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'وعد سلطان العتيبي', phone: '0580802330', university_id: '445927084', email: 'Waadv2@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'إيمان نجيب العساف', phone: '0545990914', university_id: '2359117419', email: 'emanalassaff5@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'أصيل علي القحطاني', phone: '0543350079', university_id: '446103058', email: 'qh.aseel1@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'لينا محمد العفتان', phone: '0533764047', university_id: '445204295', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'فيّ عبدالله العمراني', phone: '0582291987', university_id: '445202127', email: 'Fay.alomrani@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'غلا هادي الخذامي', phone: '0550780949', university_id: '447200027', email: 'galahl610@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'نجد عبدالله المسعود', phone: '0506480862', university_id: '445202385', email: 'najd2005almas@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'نجود اسماعيل السماعيل', phone: '0505221176', university_id: '446927152', email: 'nj1426ood@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
  { full_name: 'هديل فيصل القحطاني', phone: '0537978824', university_id: '446203051', email: 'Hadeel.alqhtani206@gmail.com', committees: [{ name_en: PR, role: 'member' }] },
];

export const QD_MEMBERS: SeedMember[] = [
  { full_name: 'شوق موسى ال مسيعد', phone: '0561918246', university_id: '442927748', email: 'iishgshg47@gmail.com', committees: [{ name_en: QD, role: 'member' }] },
  { full_name: 'دينا محمد الشهري', phone: '0550332234', university_id: '445201628', email: 'Deena05m@gmail.com', committees: [{ name_en: QD, role: 'member' }] },
  { full_name: 'شاديه شباب البقمي', phone: '0501544326', university_id: '444200915', email: 'Shadiah2005@icloud.com', committees: [{ name_en: QD, role: 'member' }] },
  { full_name: 'سارة عبدالله الحوطي', phone: '0533194041', university_id: '446206547', email: 'ssaraabdullah711@gmail.com', committees: [{ name_en: QD, role: 'member' }] },
  { full_name: 'نوف محمد بن معمر', phone: '0532685572', university_id: '446207300', email: 'Noufmou3@gmail.com', committees: [{ name_en: QD, role: 'member' }] },
  { full_name: 'دانة محمد الحوشاني', phone: '0581600323', university_id: '447201459', committees: [{ name_en: QD, role: 'member' }] },
  { full_name: 'أفنان سلمان العنقري', phone: '0581129252', university_id: '445202351', committees: [{ name_en: QD, role: 'member' }] },
  { full_name: 'ساره عبدالعزيز العامر', phone: '0507740821', university_id: '445204296', email: 'Seveen7v@hotmail.com', committees: [{ name_en: QD, role: 'member' }] },
  { full_name: 'خوله حسين قنطاش', phone: '0500749135', university_id: '445203438', committees: [{ name_en: QD, role: 'member' }] },
  { full_name: 'روان مضر العاني', phone: '0535661946', university_id: '445206345', email: 'Rawan.idk@yahoo.com', committees: [{ name_en: QD, role: 'member' }] },
  { full_name: 'مريم ابوبكر باجنيد', phone: '570187906', university_id: '445203788', email: 'maryambajneed@gmail.com', committees: [{ name_en: QD, role: 'member' }] },
];

export const AM_MEMBERS: SeedMember[] = [
  { full_name: 'رهف عليان مجرشي', phone: '532265774', university_id: '444926477', email: 'Vxx3849@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'دانا بندر المطيري', phone: '0551691041', university_id: '445200625', email: 'alrhymydana@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'سارة مرزوق المطيري', phone: '0566214561', university_id: '444927065', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'منى زياد جبلاوي', phone: '0552290062', university_id: '446208041', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'يُمن حديد', phone: '0502052210', university_id: '445206283', email: 'hadidyumn@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'هيفاء خالد السعدون', phone: '0541200536', university_id: '445203169', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'عبدالرحمن بن فهد العتيبي', phone: '0552487259', university_id: '445105243', email: 'otbabdulrahman709@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'يارا سعد القرون', phone: '0534322522', university_id: '446202457', email: 'yarasaadd1@outlook.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'العنود عبدالرحمم الرويس', phone: '0509600737', university_id: '436201149', email: 'Anoudabdulrahmn@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'شذا سعود المنيف', phone: '0565027577', university_id: '1133691905', email: 'Shgnt11@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'مرام سامي السعيد', phone: '0557346527', university_id: '447925680', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'ريوف ابراهيم الغميان', phone: '0551986035', university_id: '445200979', email: 'newreyof@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'جود راشد العنزي', phone: '0559672250', university_id: '446206662', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'مرام عايد الخثعمي', phone: '0551243040', university_id: '446204938', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'افنان عبدالرحمن الحريقي', phone: '0550098878', university_id: '446202434', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'اسماء حازم سعيد', phone: '0543799091', university_id: '446207404', email: 'Asmasaeed2022@outlook.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'ابرار محمد العتيبي', phone: '551097698', university_id: '445201659', email: 'aabr.0@icloud.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'فاطمة عبدالعزيز المجيش', phone: '0501961589', university_id: '447205060', email: 'Fatimaabdulaziz131@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'شهد محمد القحطاني', phone: '0531827885', university_id: '445202759', email: 'Mhmahx66@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'عريب ابراهيم الشيحه', phone: '580858860', university_id: '445928512', email: 'Areebalshihah6@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'الهنوف احمد البشيري', phone: '503031250', university_id: '447204195', email: 'Hanoufxiia@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'رهف محمد ناجي', phone: '0508745275', university_id: '447205750', email: 'Rms827100@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'رزاز طارق فضل الله محمد', phone: '0581980233', university_id: '446208016', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'البتول اكرم كاتب', phone: '0580392679', university_id: '447203002', email: 'albatoolkateb62@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'طيف عبدالله الشنقيطي', phone: '0566819344', university_id: '445203360', email: 'taifa7788aa@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'جنان عبدالله الغربي', phone: '502916525', university_id: '445200658', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'شمس محمد التويجري', phone: '0583592829', university_id: '446204808', email: 'shams6wj@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'احمد حسين العويشي', phone: '0576415191', university_id: '446105390', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'سدره حسان الحديد', phone: '0580827725', university_id: '446208018', email: 'sab0naa9@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'نوره وليد بن دوخي', phone: '0567173719', university_id: '447203516', email: 'wadomyluvs@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'رزان معيض الشهري', phone: '0501775852', university_id: '446206502', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'تيماء بلال المحروق', phone: '0506420103', university_id: '444204724', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'شجون عبدالعزيز الشبانات', phone: '0555234390', university_id: '447202431', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'طيف عبدالعزيز القاسم', phone: '0502113225', university_id: '444202116', email: 'Teef1492@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'فرح عبدالله اليوسف', phone: '0556706606', university_id: '445201608', email: 'farahyousef2999@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'نوف سعد القحطاني', phone: '0566552473', university_id: '446207121', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'رزان مصلح المطيري', phone: '0565835543', university_id: '447204028', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'الكادي علي العتيبي', phone: '0501628065', university_id: '447201482', email: 'vv7vv8kkll@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'شهد تركي بن طالب', phone: '0502932640', university_id: '443204257', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'هيفاء عبد الكريم الشبانات', phone: '0537307619', university_id: '444926630', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'جود عبدالله العصيل', phone: '0591325500', university_id: '444927190', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'سلطانه خالد الكلدي', phone: '0538049566', university_id: '446203004', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'ارام عماد البراهيم', phone: '0539114714', university_id: '442200770', email: 'Aramalbr@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'نوير سعد السهلي', phone: '0554787117', university_id: '445203925', email: 'noier1722sf@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'بدور خالد الجندل', phone: '0595519952', university_id: '445203627', email: 'Budoor.aljandal@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'اميره علي مهاوش', phone: '0502367863', university_id: '445203200', email: 'amerhali320@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'حنين عمر الطحيني', phone: '0502900836', university_id: '445200836', email: 'm.hanomr@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'غلا محمد المنصور', phone: '0531264122', university_id: '445204068', email: 'ghala.almansour@icloud.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'ليان خالد الشمري', phone: '0501346926', university_id: '447201902', email: 'Layanalshammari5@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'يارا إبراهيم القباني', phone: '534549170', university_id: '447202915', email: 'Y1309525@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'منيره ثلاب الشرافي', phone: '0541514674', university_id: '445203566', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'مؤيد جمعة الطقيقي', phone: '0551707009', university_id: '446103340', email: 'Moaiad498@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'رويدا سلطان الدعلان', phone: '0532065668', university_id: '447203256', email: 'Rowaidas27@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'جنى عبدالعزيز الهويش', phone: '0509042120', university_id: '446202931', email: 'Janaalhw@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'سعد بن ابوناصر', phone: '554612435', university_id: '447101474', email: 'sa1759225@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
  { full_name: 'ريم فهد القحطاني', phone: '532145457', university_id: '446206003', email: 'rf2413854@gmail.com', committees: [{ name_en: AM, role: 'member' }] },
];

export const TE_MEMBERS: SeedMember[] = [
  { full_name: 'عائشة محمد ابراهيم', phone: '0551298562', university_id: '444204041', email: 'Aishamohamed.ib@outlook.com', committees: [{ name_en: TE, role: 'member' }] },
  { full_name: 'محمد عبدالله آل رشود', phone: '0556774847', university_id: '444101749', email: 'moalrushud@gmail.com', committees: [{ name_en: TE, role: 'member' }] },
  { full_name: 'عالية خالد القحطاني', phone: '0501083355', university_id: '446202367', email: 'akaq427@gmail.com', committees: [{ name_en: TE, role: 'member' }] },
  // محمد المحيذيف is the APP ADMIN — gets president-equivalent permissions
  { full_name: 'محمد عبدالله المحيذيف', phone: '0530466740', university_id: '446103998', email: 'Mohammed.almuhaythif@gmail.com', committees: [{ name_en: TE, role: 'member' }], club_role: 'app_admin' },
  { full_name: 'دلال محمد بن لويبه', phone: '0504491488', university_id: '446206804', email: 'lwaibhdalal@gmail.com', committees: [{ name_en: TE, role: 'member' }] },
];

export const GD_MEMBERS: SeedMember[] = [
  { full_name: 'هيا علي القحطاني', phone: '0507317715', university_id: '444927039', email: 'Hy77.8@hotmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'ريانه فايز العنزي', phone: '0549070985', university_id: '446206791', email: 'rrayanh1@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'جنا خالد الشبانات', phone: '0505438122', university_id: '444202636', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'رنا هيثم الربيعه', phone: '0502445207', university_id: '446201281', email: 'Rrana11220@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'تولين محمد الشهري', phone: '0559230627', university_id: '446205370', email: 'ToleenMAlshehri@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'يوسف حسن يحيى ال بلابل', phone: '0530303895', university_id: '446107429', email: 'ywsfhsnalblabl8@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'رنا خالد بن نخيلان', phone: '0599271188', university_id: '446204883', email: 'rana99919929@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'هديل حمد الحناكي', phone: '0567146691', university_id: '446202083', email: 'alhenakihadeel@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'ساره عائض القحطاني', phone: '0552690204', university_id: '446203127', email: 'alqhtanisoso21@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'اروى نايف الغامدي', phone: '0558081771', university_id: '444200245', email: 'Arwa.Nayef.s@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'منيره عبدالعزيز العيسى', phone: '0568989089', university_id: '455201044', email: 'mxnirah11@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'ساره فهد بن شنار', phone: '0505323805', university_id: '447205338', email: 'sa43ra11@icloud.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'ليان بنت محمد الوطيان', phone: '0557701261', university_id: '447201460', email: 'Laymsub@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'جوري محمد ال سفيان', phone: '0533246936', university_id: '446203992', email: 'joorij607@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
  { full_name: 'دانه عبدالكريم الزهراني', phone: '0508631563', university_id: '445203377', email: 'danaalzahrani2002@gmail.com', committees: [{ name_en: GD, role: 'member' }] },
];

export const MEDIA_MEMBERS: SeedMember[] = [
  // Visual Identity sub-team members
  { full_name: 'نوف سعود المطيري', phone: '0557386141', university_id: '444201049', email: 'noufn8988@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'هيا عبدالاله الراشد', phone: '552126083', university_id: '445202787', email: 'Haya_alrashed@outlook.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'نورة بنت وليد بن شاهين', phone: '0501601797', university_id: '446201925', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'فاطمة تركي الكريمي', phone: '0563086620', university_id: '447202479', email: 'Fatmahalkarimi@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'جمانه صلاح الدين وجدي', phone: '0570986987', university_id: '447205725', email: 'jomanas309@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  // Photo/Video sub-team members
  { full_name: 'شهد محمد الزاكي', phone: '0570717860', university_id: '447202426', email: 'shadzakki2018@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'ليان سلطان العاتي', phone: '532313118', university_id: '447926963', email: 'leye7181@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'حنان حسين الشقراوي', phone: '0551063873', university_id: '445202087', email: 'hanan.alshgrawi33@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'سلوى عبدالرحمن دع', phone: '0534616029', university_id: '447205791', email: 'salwadaa236@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'رغد سبيل السعدي', phone: '548614855', university_id: '444927123', email: 'yiirii2020@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'رزان علي فقيه', phone: '0557139179', university_id: '446203530', email: 'rzanfqyh0@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'ساره ناصر الدوسري', phone: '530055299', university_id: '447203263', email: 'aburashed056923@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'ليان سعود الاحمد', phone: '500544896', university_id: '446202974', email: 'lyansa226@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  // Content writers
  { full_name: 'هيا عبدالعزيز الوهيبي', phone: '0501758924', university_id: '446204927', email: 'haaw07@hotmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'شادن محمد المنهالي', phone: '0500391766', university_id: '445206332', email: 'shadenm618@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'ريناد زايد السبيعي', phone: '0559801392', university_id: '445201247', email: 'ranalsbby@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'نوف فهد بن غنام', phone: '0532021165', university_id: '445201771', email: 'nouf_fhg@hotmail.com', committees: [{ name_en: ME, role: 'member' }] },
  // Account managers
  { full_name: 'يارا عاصم المقحم', phone: '0573573011', university_id: '447202690', email: 'yalmuqhim@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'رغد علي باجبع', phone: '550024209', university_id: '446203255', email: 'R.a.g.h.a.d.a.l.i.b.j.a.b.a.2020@gmail.com', committees: [{ name_en: ME, role: 'member' }] },
];

// Multi-committee members (ONE user, multiple memberships).
export const MULTI_COMMITTEE: SeedMember[] = [
  {
    full_name: 'ديالا خلف السلمي',
    phone: '0581312082',
    university_id: '445201804',
    email: 'dayalaalsulamio5@gmail.com',
    committees: [
      { name_en: ME, role: 'member' }, // also vice of permanent team below
      { name_en: QD, role: 'member' },
    ],
  },
  {
    full_name: 'نورة عبدالعزيز العجمي',
    phone: '0559885075',
    university_id: '445201237',
    email: 'Noura.Alajmi3205@gmail.com',
    committees: [
      { name_en: HR, role: 'member' },
      { name_en: QD, role: 'member' },
    ],
  },
  {
    full_name: 'أحمد يوسف العضياني',
    phone: '508440285',
    university_id: '442102790',
    email: 'Ahmedsoftwareengineer2025@gmail.com',
    committees: [
      { name_en: PM, role: 'member' },
      { name_en: TE, role: 'member' },
    ],
  },
  {
    full_name: 'حصه عبدالرحمن النزهان',
    phone: '0550781522',
    university_id: '446204358',
    email: 'hsa55h@icloud.com',
    committees: [
      { name_en: AM, role: 'member' },
      { name_en: ME, role: 'member' }, // content writers sub-team
    ],
  },
];

// Permanent team leaders/vices NOT in committee rosters above — create them too.
export const TEAM_ONLY_LEADERS: SeedMember[] = [
  { full_name: 'لينا القحطاني', phone: '504631880', university_id: '444202088', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'ديما الدويش', phone: '551507105', university_id: '446204886', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'عبدالله السبيعي', phone: '557931014', university_id: '445105905', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'سارة المقري', phone: '545127162', university_id: '446202651', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'منار القحطاني', phone: '532899523', university_id: '442200186', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'سارة القرني', phone: '502864941', university_id: '446206096', committees: [{ name_en: ME, role: 'member' }] },
  { full_name: 'غالية الخرعان', phone: '533661977', university_id: '445203858', committees: [{ name_en: ME, role: 'member' }] },
];

export const ALL_MEMBERS: SeedMember[] = [
  ...BOARD,
  ...LEADERSHIP,
  ...HEADS,
  ...HR_MEMBERS,
  ...PM_MEMBERS,
  ...PR_MEMBERS,
  ...QD_MEMBERS,
  ...AM_MEMBERS,
  ...TE_MEMBERS,
  ...GD_MEMBERS,
  ...MEDIA_MEMBERS,
  ...MULTI_COMMITTEE,
  ...TEAM_ONLY_LEADERS,
];

// ─── Permanent sub-teams under اللجنة الإعلامية (Media) ─────────────
export type PermanentTeam = {
  name: string;
  description: string;
  leader_university_id: string;
  vice_university_id: string;
};

export const PERMANENT_TEAMS: PermanentTeam[] = [
  {
    name: 'فريق الهوية البصرية',
    description: 'تصميم وإدارة الهوية البصرية للنادي',
    leader_university_id: '444202088', // لينا القحطاني
    vice_university_id:   '445201804', // ديالا السلمي
  },
  {
    name: 'فريق التصوير والمونتاج',
    description: 'تصوير ومونتاج الفعاليات',
    leader_university_id: '446204886', // ديما الدويش
    vice_university_id:   '445105905', // عبدالله السبيعي
  },
  {
    name: 'فريق كتابة المحتوى',
    description: 'كتابة وإعداد المحتوى للقنوات',
    leader_university_id: '446202651', // سارة المقري
    vice_university_id:   '442200186', // منار القحطاني
  },
  {
    name: 'فريق إدارة الحسابات',
    description: 'إدارة حسابات النادي على وسائل التواصل',
    leader_university_id: '446206096', // سارة القرني
    vice_university_id:   '445203858', // غالية الخرعان
  },
];
