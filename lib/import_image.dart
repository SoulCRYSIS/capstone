import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_downloader_web/image_downloader_web.dart';
import 'package:image_size_getter/image_size_getter.dart' as image_size_getter;
import 'package:stroke_text/stroke_text.dart';
import 'package:widgets_to_image/widgets_to_image.dart';

class ImportImage extends StatefulWidget {
  const ImportImage({Key? key}) : super(key: key);
  @override
  State<ImportImage> createState() => _ImportImageState();
}

class _ImportImageState extends State<ImportImage> {
  Uint8List? image;
  List<List<Offset>> points = [];
  Offset refPoint1 = const Offset(100, 50);
  Offset refPoint2 = const Offset(150, 100);
  double? refLength;
  bool isSaving = false;
  double zoom = 1;
  List<List<double>>? depthData;
  bool showDepth = false;
  double imageToDepthRatio = 1;
  double hFov = 90;
  double vFov = 90;
  double? width;
  double? height;

  final GlobalKey stackKey = GlobalKey();
  final GlobalKey imageKey = GlobalKey();
  final captureController = WidgetsToImageController();
  final transformationController = TransformationController();

  double distancePixel(Offset p1, Offset p2) {
    return sqrt(pow(p1.dx - p2.dx, 2) + pow(p1.dy - p2.dy, 2));
  }

  double distanceAtPoint(Offset p) {
    final x = min(depthData!.first.length - 1, p.dx / imageToDepthRatio);
    final y = min(depthData!.length - 1, p.dy / imageToDepthRatio);
    return depthData![y.round()][x.round()];
  }

  double get centerX => width! / 2;
  double get centerY => height! / 2;

  /// in radians
  double angleBetweenTwoPoints(Offset p1, Offset p2) {
    final hFovRadian = hFov * pi / 180;
    final vFovRadian = vFov * pi / 180;

    final p1HAngle = (p1.dx - centerX) * hFovRadian / width!;
    final p1VAngle = (p1.dy - centerY) * vFovRadian / height!;
    final p2HAngle = (p2.dx - centerX) * hFovRadian / width!;
    final p2VAngle = (p2.dy - centerY) * vFovRadian / height!;

    return acos(
      cos(p1HAngle) * cos(p2HAngle) * cos(p1VAngle - p2VAngle) +
          sin(p1HAngle) * sin(p2HAngle),
    );
  }

  /// in meters
  double distanceLidar(Offset p1, Offset p2) {
    final angle = angleBetweenTwoPoints(p1, p2);

    final p1Distance = distanceAtPoint(p1);
    final p2Distance = distanceAtPoint(p2);

    final distance = sqrt(pow(p1Distance, 2) +
        pow(p2Distance, 2) -
        2 * p1Distance * p2Distance * cos(angle));

    return distance;
  }

  double distance(Offset p1, Offset p2) {
    if (refLength == null) {
      return distancePixel(p1, p2);
    }
    return distancePixel(p1, p2) *
        refLength! /
        distancePixel(refPoint1, refPoint2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
              child: Center(
            child: image == null
                ? const Text('unselected')
                : InteractiveViewer(
                    transformationController: transformationController,
                    onInteractionUpdate: (details) {
                      setState(() {
                        zoom =
                            transformationController.value.getMaxScaleOnAxis();
                      });
                    },
                    child: WidgetsToImage(
                        controller: captureController,
                        child: Stack(
                          key: stackKey,
                          children: [
                            LayoutBuilder(builder: (context, constraints) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final imageSize =
                                    imageKey.currentContext!.size!;
                                setState(() {
                                  imageToDepthRatio =
                                      imageSize.height / depthData!.length;
                                  width = imageSize.width;
                                  height = imageSize.height;
                                });
                              });
                              return Image.memory(
                                key: imageKey,
                                image!,
                              );
                            }),
                            if (depthData != null && showDepth)
                              DepthImage(
                                depthData!,
                                imageToDepthRatio,
                              ),
                            CustomPaint(
                              painter: Line(
                                refPoint1,
                                refPoint2,
                              ),
                            ),
                            CustomPaint(
                              painter: Lines(points),
                            ),
                            if (depthData != null)
                              Positioned(
                                left: refPoint1.dx - 10,
                                top: refPoint1.dy - 10,
                                child: StrokeText(
                                  strokeWidth: 2,
                                  text:
                                      '${distanceAtPoint(refPoint1).toStringAsFixed(3)} m',
                                ),
                              ),
                            if (depthData != null)
                              Positioned(
                                left: refPoint2.dx,
                                top: refPoint2.dy,
                                child: StrokeText(
                                  strokeWidth: 2,
                                  text:
                                      '${distanceAtPoint(refPoint2).toStringAsFixed(3)} m',
                                ),
                              ),
                            Positioned(
                              left: refPoint1.dx - 5,
                              top: refPoint1.dy - 5,
                              child: Draggable(
                                feedback: const CirclePoint(),
                                onDragEnd: (dragDetails) {
                                  RenderBox box = stackKey.currentContext!
                                      .findRenderObject() as RenderBox;
                                  Offset localOffset =
                                      box.globalToLocal(dragDetails.offset);
                                  final imageSize =
                                      imageKey.currentContext!.size!;
                                  setState(() {
                                    var newPoint = (localOffset +
                                        const Offset(5, 5) / zoom);
                                    refPoint1 = Offset(
                                        newPoint.dx.clamp(0.0, imageSize.width),
                                        newPoint.dy
                                            .clamp(0.0, imageSize.height));
                                  });
                                },
                                child: const CirclePoint(),
                              ),
                            ),
                            Positioned(
                              left: refPoint2.dx - 5,
                              top: refPoint2.dy - 5,
                              child: Draggable(
                                feedback: const CirclePoint(),
                                onDragEnd: (dragDetails) {
                                  RenderBox box = stackKey.currentContext!
                                      .findRenderObject() as RenderBox;
                                  Offset localOffset =
                                      box.globalToLocal(dragDetails.offset);

                                  final imageSize =
                                      imageKey.currentContext!.size!;

                                  setState(() {
                                    var newPoint = (localOffset +
                                        const Offset(5, 5) / zoom);
                                    refPoint2 = Offset(
                                        newPoint.dx.clamp(0.0, imageSize.width),
                                        newPoint.dy
                                            .clamp(0.0, imageSize.height));
                                  });
                                },
                                child: const CirclePoint(),
                              ),
                            ),
                            Positioned(
                              left: refPoint1.dx,
                              top: refPoint1.dy,
                              child: Transform.rotate(
                                alignment: Alignment.topLeft,
                                angle: atan2(refPoint2.dy - refPoint1.dy,
                                    refPoint2.dx - refPoint1.dx),
                                child: Container(
                                  alignment: Alignment.center,
                                  width: distancePixel(refPoint1, refPoint2),
                                  child: StrokeText(
                                    strokeWidth: 2,
                                    text: depthData == null || width == null
                                        ? distance(refPoint1, refPoint2)
                                            .toStringAsFixed(1)
                                        : '${distanceLidar(refPoint1, refPoint2).toStringAsFixed(3)} m (${(angleBetweenTwoPoints(refPoint1, refPoint2) * 180 / pi).toStringAsFixed(1)})',
                                  ),
                                ),
                              ),
                            ),
                            for (List<Offset> point in points) ...[
                              Positioned(
                                left: point[0].dx - 5,
                                top: point[0].dy - 5,
                                child: Draggable(
                                  feedback: const CirclePoint(),
                                  onDragEnd: (dragDetails) {
                                    RenderBox box = stackKey.currentContext!
                                        .findRenderObject() as RenderBox;
                                    Offset localOffset =
                                        box.globalToLocal(dragDetails.offset);
                                    final imageSize =
                                        imageKey.currentContext!.size!;
                                    setState(() {
                                      var newPoint = (localOffset +
                                          const Offset(5, 5) / zoom);
                                      point[0] = Offset(
                                          newPoint.dx
                                              .clamp(0.0, imageSize.width),
                                          newPoint.dy
                                              .clamp(0.0, imageSize.height));
                                    });
                                  },
                                  child: const CirclePoint(),
                                ),
                              ),
                              Positioned(
                                left: point[1].dx - 5,
                                top: point[1].dy - 5,
                                child: Draggable(
                                  feedback: const CirclePoint(),
                                  onDragEnd: (dragDetails) {
                                    RenderBox box = stackKey.currentContext!
                                        .findRenderObject() as RenderBox;
                                    Offset localOffset =
                                        box.globalToLocal(dragDetails.offset);
                                    setState(() {
                                      var newPoint = (localOffset +
                                          const Offset(5, 5) / zoom);
                                      final imageSize =
                                          imageKey.currentContext!.size!;
                                      point[1] = Offset(
                                          newPoint.dx
                                              .clamp(0.0, imageSize.width),
                                          newPoint.dy
                                              .clamp(0.0, imageSize.height));
                                    });
                                  },
                                  child: const CirclePoint(),
                                ),
                              ),
                              Positioned(
                                left: point[0].dx,
                                top: point[0].dy,
                                child: Transform.rotate(
                                  alignment: Alignment.topLeft,
                                  angle: atan2(point[1].dy - point[0].dy,
                                      point[1].dx - point[0].dx),
                                  child: Container(
                                    alignment: Alignment.center,
                                    width: distancePixel(point[0], point[1]),
                                    child: StrokeText(
                                      strokeWidth: 2,
                                      text: depthData == null || width == null
                                          ? distance(point[0], point[1])
                                              .toStringAsFixed(1)
                                          : '${distanceLidar(point[0], point[1]).toStringAsFixed(3)} m (${(angleBetweenTwoPoints(point[0], point[1]) * 180 / pi).toStringAsFixed(1)})',
                                    ),
                                  ),
                                ),
                              ),
                            ]
                          ],
                        )),
                  ),
          )),
          const VerticalDivider(),
          Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ImagePicker(
                  onPicked: (file, w, h) {
                    setState(() {
                      image = file;
                    });
                  },
                ),
                verticalSpace,
                ElevatedButton(
                  onPressed: () async {
                    FilePickerResult? result =
                        await FilePicker.platform.pickFiles(
                      allowMultiple: false,
                      type: FileType.custom,
                      allowedExtensions: ['csv'],
                    );

                    if (result != null) {
                      PlatformFile file = result.files.first;

                      final input = file.bytes;
                      final contents = String.fromCharCodes(input!);

                      List<String> rows = contents.split('\n');
                      List<List<double>> array = rows
                          .map((row) => row
                              .split(',')
                              .map((e) => double.parse(e))
                              .toList())
                          .toList();

                      setState(() {
                        depthData = array;
                      });
                    }
                  },
                  child: const Text('Pick CSV'),
                ),
                verticalSpace,
                Row(
                  children: [
                    const Text('Show depth'),
                    Checkbox(
                        value: showDepth,
                        onChanged: (value) => setState(() {
                              showDepth = value!;
                            })),
                  ],
                ),
                verticalSpace,
                TextFormField(
                  initialValue: '90',
                  decoration: const InputDecoration(
                    labelText: 'Horizontal FOV',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[0-9.]"))
                  ],
                  onChanged: (value) {
                    setState(() {
                      hFov = double.tryParse(value) ?? 90;
                    });
                  },
                ),
                verticalSpace,
                TextFormField(
                  initialValue: '90',
                  decoration: const InputDecoration(
                    labelText: 'Vertical FOV',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[0-9.]"))
                  ],
                  onChanged: (value) {
                    setState(() {
                      vFov = double.tryParse(value) ?? 90;
                    });
                  },
                ),
                verticalSpace,
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Reference length',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r"[0-9.]"))
                  ],
                  onChanged: (value) {
                    setState(() {
                      refLength = double.tryParse(value);
                    });
                  },
                ),
                verticalSpace,
                Text(
                    'Ref length: ${distancePixel(refPoint1, refPoint2).toStringAsFixed(1)} px'),
                verticalSpace,
                isSaving
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            isSaving = true;
                          });
                          final bytes = await captureController.capture();

                          await WebImageDownloader.downloadImageFromUInt8List(
                              uInt8List: bytes!, name: 'image');

                          setState(() {
                            isSaving = false;
                          });
                        },
                        child: const Text('Save'),
                      ),
                verticalSpace,
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pixel',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'w/o LiDAR',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'LiDAR',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Angle',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 40),
                  ],
                ),
                if (image != null)
                  Column(
                    children: [
                      [refPoint1, refPoint2],
                      ...points
                    ].map(
                      (e) {
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                distancePixel(e[0], e[1]).toStringAsFixed(1),
                                textAlign: TextAlign.end,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                distance(e[0], e[1]).toStringAsFixed(1),
                                textAlign: TextAlign.end,
                              ),
                            ),
                            depthData == null || width == null
                                ? const Spacer()
                                : Expanded(
                                    child: Text(
                                      distanceLidar(e[0], e[1])
                                          .toStringAsFixed(3),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                            depthData == null || width == null
                                ? const Spacer()
                                : Expanded(
                                    child: Text(
                                      (angleBetweenTwoPoints(e[0], e[1]) *
                                              180 /
                                              pi)
                                          .toStringAsFixed(1),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                            IconButton(
                              onPressed: () => setState(() {
                                points.remove(e);
                              }),
                              icon: const Icon(Icons.delete),
                            )
                          ],
                        );
                      },
                    ).toList(),
                  ),
                verticalSpace,
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      points
                          .add([const Offset(50, 50), const Offset(100, 100)]);
                    });
                  },
                  child: const Text('Add Line'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CirclePoint extends StatelessWidget {
  const CirclePoint({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
    );
  }
}

const verticalSpace = SizedBox(height: 16);

class Lines extends CustomPainter {
  final List<List<Offset>> points;

  Lines(this.points);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 4
      ..color = Colors.green;

    for (List<Offset> point in points) {
      canvas.drawLine(point[0], point[1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class Line extends CustomPainter {
  final Offset p1;
  final Offset p2;

  Line(
    this.p1,
    this.p2,
  );

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 4
      ..color = Colors.red;

    canvas.drawLine(p1, p2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class ImagePicker extends StatelessWidget {
  const ImagePicker({
    required this.onPicked,
    Key? key,
  }) : super(key: key);

  final void Function(Uint8List file, int width, int height) onPicked;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
          );
          if (result == null) {
            return;
          }

          Uint8List bytes = result.files.first.bytes!;

          final size = image_size_getter.ImageSizeGetter.getSize(
              image_size_getter.MemoryInput(bytes));

          onPicked(
            bytes,
            size.width,
            size.height,
          );
        },
        child: const Text('Pick image'),
      ),
    );
  }
}

class HeatMapPainter extends CustomPainter {
  final List<List<double>> data;
  final double cellSize;
  late final double maxValue;
  late final double minValue;
  late final double range;

  HeatMapPainter({required this.data, this.cellSize = 1}) {
    maxValue = data.expand((row) => row).reduce(max);
    minValue = data.expand((row) => row).reduce(min);
    range = maxValue - minValue;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < data.length; i++) {
      for (int j = 0; j < data[i].length; j++) {
        final paint = Paint()
          ..color = _getColorFromValue((data[i][j] - minValue) / range);
        final rect =
            Rect.fromLTWH(j * cellSize, i * cellSize, cellSize, cellSize);
        canvas.drawRect(rect, paint);
      }
    }
  }

  Color _getColorFromValue(double value) {
    var h = (1.0 - value) * 360;
    return HSLColor.fromAHSL(0.8, h, 1, 0.5).toColor();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DepthImage extends StatelessWidget {
  final List<List<double>> data;
  final double cellSize;

  const DepthImage(this.data, this.cellSize, {super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // assuming all rows have equal length
      painter: HeatMapPainter(data: data, cellSize: cellSize),
    );
  }
}
