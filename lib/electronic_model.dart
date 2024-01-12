class ElectronicModel {
  String? name, id, image;
  num? amount, watt;
  num? totalToolsKwh;
  bool? condition;
  int? runTime;
  int? hours;

  ElectronicModel(
      {required this.name,
      required this.id,
      this.hours,
      this.runTime,
      required this.image,
      required this.amount,
      required this.totalToolsKwh,
      required this.condition,
      required this.watt});
}
