/// Metadata used to make a com0com client COM port look like a real POS printer
/// to Windows SetupAPI / kiosk auto-discovery (SAM4S GCUBE-102).
class PosPrinterDisguiseProfile {
  const PosPrinterDisguiseProfile({
    required this.deviceDesc,
    required this.friendlyName,
  });

  /// Matches default [PosPrinterConfig.printerName] in toppenkiosk.
  static const PosPrinterDisguiseProfile kioskDefault = PosPrinterDisguiseProfile(
    deviceDesc: 'SAM4S GCUBE-102 USB Receipt Printer',
    friendlyName: 'SAM4S GCUBE-102 USB POS Printer',
  );

  final String deviceDesc;
  final String friendlyName;
}
