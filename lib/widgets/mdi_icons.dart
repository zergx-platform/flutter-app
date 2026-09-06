import 'package:flutter/material.dart';

/// Font family for the vendored Material Design Icons webfont.
const String kMdiFontFamily = 'MaterialDesignIcons';

/// Minimal subset of MDI monochrome icons, defined as plain [IconData]
/// constants (code points from materialdesignicons-webfont.ttf). We vendor the
/// font and define these ourselves instead of using the `material_design_icons
/// _flutter` package, whose `_MdiIconData extends IconData` no longer compiles
/// on this Flutter SDK (IconData became final). Direct `const IconData(...)`
/// constructors keep the tree shaker happy.
class MdiIcon {
  const MdiIcon._();

  static const IconData androidStudio = IconData(0xf0034, fontFamily: kMdiFontFamily);
  static const IconData codeBraces = IconData(0xf0169, fontFamily: kMdiFontFamily);
  static const IconData console = IconData(0xf018d, fontFamily: kMdiFontFamily);
  static const IconData database = IconData(0xf01bc, fontFamily: kMdiFontFamily);
  static const IconData docker = IconData(0xf0868, fontFamily: kMdiFontFamily);
  static const IconData dotNet = IconData(0xf0aae, fontFamily: kMdiFontFamily);
  static const IconData fileCode = IconData(0xf022e, fontFamily: kMdiFontFamily);
  static const IconData fileDocument = IconData(0xf0219, fontFamily: kMdiFontFamily);
  static const IconData fileExcel = IconData(0xf021b, fontFamily: kMdiFontFamily);
  static const IconData fileImage = IconData(0xf021f, fontFamily: kMdiFontFamily);
  static const IconData fileMusic = IconData(0xf0223, fontFamily: kMdiFontFamily);
  static const IconData fileOutline = IconData(0xf0224, fontFamily: kMdiFontFamily);
  static const IconData filePdfBox = IconData(0xf0226, fontFamily: kMdiFontFamily);
  static const IconData filePowerpoint = IconData(0xf0227, fontFamily: kMdiFontFamily);
  static const IconData fileTable = IconData(0xf0c7e, fontFamily: kMdiFontFamily);
  static const IconData fileVideo = IconData(0xf022b, fontFamily: kMdiFontFamily);
  static const IconData fileWord = IconData(0xf022c, fontFamily: kMdiFontFamily);
  static const IconData fileXmlBox = IconData(0xf1b4b, fontFamily: kMdiFontFamily);
  static const IconData folderZip = IconData(0xf06eb, fontFamily: kMdiFontFamily);
  static const IconData functionVariant = IconData(0xf0871, fontFamily: kMdiFontFamily);
  static const IconData graphql = IconData(0xf0877, fontFamily: kMdiFontFamily);
  static const IconData kubernetes = IconData(0xf10fe, fontFamily: kMdiFontFamily);
  static const IconData languageC = IconData(0xf0671, fontFamily: kMdiFontFamily);
  static const IconData languageCpp = IconData(0xf0672, fontFamily: kMdiFontFamily);
  static const IconData languageCsharp = IconData(0xf031b, fontFamily: kMdiFontFamily);
  static const IconData languageCss3 = IconData(0xf031c, fontFamily: kMdiFontFamily);
  static const IconData languageGo = IconData(0xf07d3, fontFamily: kMdiFontFamily);
  static const IconData languageHaskell = IconData(0xf0c92, fontFamily: kMdiFontFamily);
  static const IconData languageHtml5 = IconData(0xf031d, fontFamily: kMdiFontFamily);
  static const IconData languageJava = IconData(0xf0b37, fontFamily: kMdiFontFamily);
  static const IconData languageJavascript = IconData(0xf031e, fontFamily: kMdiFontFamily);
  static const IconData languageKotlin = IconData(0xf1219, fontFamily: kMdiFontFamily);
  static const IconData languageLua = IconData(0xf08b1, fontFamily: kMdiFontFamily);
  static const IconData languageMarkdown = IconData(0xf0354, fontFamily: kMdiFontFamily);
  static const IconData languagePhp = IconData(0xf031f, fontFamily: kMdiFontFamily);
  static const IconData languagePython = IconData(0xf0320, fontFamily: kMdiFontFamily);
  static const IconData languageRuby = IconData(0xf0d2d, fontFamily: kMdiFontFamily);
  static const IconData languageRust = IconData(0xf1617, fontFamily: kMdiFontFamily);
  static const IconData languageSwift = IconData(0xf06e5, fontFamily: kMdiFontFamily);
  static const IconData languageTypescript = IconData(0xf06e6, fontFamily: kMdiFontFamily);
  static const IconData nodejs = IconData(0xf0399, fontFamily: kMdiFontFamily);
  static const IconData protocol = IconData(0xf0fd8, fontFamily: kMdiFontFamily);
  static const IconData terraform = IconData(0xf1062, fontFamily: kMdiFontFamily);
  static const IconData tools = IconData(0xf1064, fontFamily: kMdiFontFamily);
  static const IconData vuejs = IconData(0xf0844, fontFamily: kMdiFontFamily);
}
