import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_downloader_web/image_downloader_web.dart';
import 'package:stroke_text/stroke_text.dart';
import 'package:widgets_to_image/widgets_to_image.dart';

class ImportImage extends StatefulWidget {
  const ImportImage({Key? key}) : super(key: key);
  @override
  State<ImportImage> createState() => _ImportImageState();
}

class _ImportImageState extends State<ImportImage> {
  Image? image;
  List<List<Offset>> points = [];
  Offset refPoint1 = const Offset(100, 50);
  Offset refPoint2 = const Offset(150, 100);
  double? refLength;
  bool isSaving = false;
  double zoom = 1;
  List<List<double>>? depthData;
  bool showDepth = false;
  double imageToDepthRatio = 1;

  final GlobalKey stackKey = GlobalKey();
  final captureController = WidgetsToImageController();
  final transformationController = TransformationController();

  double distancePixel(Offset p1, Offset p2) {
    return sqrt(pow(p1.dx - p2.dx, 2) + pow(p1.dy - p2.dy, 2));
  }

  double distanceAtPoint(Offset p) {
    final x = p.dx / imageToDepthRatio;
    final y = p.dy / imageToDepthRatio;
    return depthData![y.round()][x.round()];
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
                      child: LayoutBuilder(builder: (context, constraints) {
                        if (depthData != null) {
                          imageToDepthRatio =
                              constraints.maxHeight / depthData!.length;
                        }

                        return Stack(
                          key: stackKey,
                          children: [
                            image!,
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
                                  setState(() {
                                    refPoint1 =
                                        localOffset + const Offset(5, 5) / zoom;
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
                                  setState(() {
                                    refPoint2 =
                                        localOffset + const Offset(5, 5) / zoom;
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
                                    text: distance(refPoint1, refPoint2)
                                        .toStringAsFixed(1),
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
                                    setState(() {
                                      point[0] = localOffset +
                                          const Offset(5, 5) / zoom;
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
                                      point[1] = localOffset +
                                          const Offset(5, 5) / zoom;
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
                                      text: distance(point[0], point[1])
                                          .toStringAsFixed(1),
                                    ),
                                  ),
                                ),
                              ),
                            ]
                          ],
                        );
                      }),
                    ),
                  ),
          )),
          const VerticalDivider(),
          Container(
            width: 200,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ImagePicker(
                  onPicked: (Image file, double height) {
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
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Reference length',
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                        'Real',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 40),
                  ],
                ),
                Column(
                  children: points
                      .map(
                        (e) => Row(
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
                            IconButton(
                              onPressed: () => setState(() {
                                points.remove(e);
                              }),
                              icon: const Icon(Icons.delete),
                            )
                          ],
                        ),
                      )
                      .toList(),
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

  final void Function(Image file, double height) onPicked;

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
          final ImageProvider imageProvider =
              MemoryImage(result.files.first.bytes!);
          final ImageStream imageStream =
              imageProvider.resolve(ImageConfiguration.empty);
          imageStream.addListener(
            ImageStreamListener(
              (ImageInfo image, bool synchronousCall) {
                onPicked(
                  Image(image: imageProvider),
                  image.image.height.toDouble(),
                );
              },
            ),
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
