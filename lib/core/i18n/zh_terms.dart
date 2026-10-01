/// 中文术语翻译表（仅用于显示，不影响筛选逻辑）。
/// 与 www/index.html 中 `ZH_TERMS` 保持一致；数据端新增词条时在此补充。
const Map<String, String> kZhTerms = {
  // body parts / category
  'back': '背部', 'cardio': '有氧', 'chest': '胸部', 'lower arms': '前臂',
  'lower legs': '小腿', 'neck': '颈部', 'shoulders': '肩部', 'upper arms': '上臂',
  'upper legs': '大腿', 'waist': '腰腹',
  // equipment
  'assisted': '辅助', 'band': '弹力带', 'barbell': '杠铃', 'body weight': '徒手',
  'bosu ball': '半圆平衡球', 'cable': '拉索', 'dumbbell': '哑铃',
  'elliptical machine': '椭圆机', 'ez barbell': '曲杆杠铃', 'hammer': '锤式器械',
  'kettlebell': '壶铃', 'leverage machine': '杠杆器械', 'medicine ball': '药球',
  'olympic barbell': '奥林匹克杠铃', 'resistance band': '阻力带', 'roller': '滚轮',
  'rope': '绳子', 'skierg machine': '划雪机', 'sled machine': '雪橇机',
  'smith machine': '史密斯机', 'stability ball': '稳定球', 'stationary bike': '动感单车',
  'stepmill machine': '爬楼机', 'tire': '轮胎', 'trap bar': '六角杠铃',
  'upper body ergometer': '上肢功率计', 'weighted': '负重', 'wheel roller': '健腹轮',
  // targets
  'abductors': '外展肌', 'abs': '腹肌', 'adductors': '内收肌', 'biceps': '肱二头肌',
  'calves': '小腿肌', 'cardiovascular system': '心血管系统', 'delts': '三角肌',
  'forearms': '前臂肌', 'glutes': '臀肌', 'hamstrings': '腘绳肌', 'lats': '背阔肌',
  'levator scapulae': '肩胛提肌', 'pectorals': '胸大肌', 'quads': '股四头肌',
  'serratus anterior': '前锯肌', 'spine': '脊柱', 'traps': '斜方肌', 'triceps': '肱三头肌',
  'upper back': '上背部',
  // muscle_group / secondary_muscles extras
  'abdominals': '腹肌群', 'ankle stabilizers': '踝关节稳定肌', 'ankles': '踝部',
  'brachialis': '肱肌', 'core': '核心', 'deltoids': '三角肌', 'feet': '足部',
  'grip muscles': '握力肌群', 'groin': '腹股沟', 'hands': '手部', 'hip flexors': '髋屈肌',
  'inner thighs': '大腿内侧', 'latissimus dorsi': '背阔肌', 'lower abs': '下腹肌',
  'lower back': '下背部', 'obliques': '腹斜肌', 'quadriceps': '股四头肌',
  'rear deltoids': '后三角肌', 'rhomboids': '菱形肌', 'rotator cuff': '肩袖肌群',
  'shins': '胫部', 'soleus': '比目鱼肌', 'sternocleidomastoid': '胸锁乳突肌',
  'trapezius': '斜方肌', 'upper chest': '上胸',
  'wrist extensors': '腕伸肌', 'wrist flexors': '腕屈肌', 'wrists': '腕部',
};

/// 英文术语 → 中文显示名；未收录时原样返回（对应 JS `zh()`）。
String zh(String? value) {
  if (value == null || value.isEmpty) return '';
  return kZhTerms[value] ?? value;
}
