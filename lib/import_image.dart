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

  final GlobalKey stackKey = GlobalKey();
  final captureController = WidgetsToImageController();
  final transformationController = TransformationController();

  double distancePixel(Offset p1, Offset p2) {
    return sqrt(pow(p1.dx - p2.dx, 2) + pow(p1.dy - p2.dy, 2));
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
                          image!,
                          CustomPaint(
                            painter: Line(
                              refPoint1,
                              refPoint2,
                            ),
                          ),
                          CustomPaint(
                            painter: Lines(points),
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
                                    point[0] =
                                        localOffset + const Offset(5, 5) / zoom;
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
                                    point[1] =
                                        localOffset + const Offset(5, 5) / zoom;
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
                      ),
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
                  onPicked: (Image file) {
                    setState(() {
                      image = file;
                    });
                  },
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

  final void Function(Image file) onPicked;

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
          onPicked(Image.memory(result.files.first.bytes!));
        },
        child: const Text('Pick image'),
      ),
    );
  }
}
