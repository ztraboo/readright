import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/app_colors.dart';
import '../utils/app_styles.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // This is just in the background to create the large orange oval for some visual interest.
            Positioned(
                left: -455,
                top: 400,
                child: Container(
                  width: 1303,
                  height: 764,
                  decoration: ShapeDecoration(
                    color: AppColors.primaryOrange,
                    shape: OvalBorder(),
                  ),
                ),
              ),
            // Layout the main content in a column.  
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 96.0),
                  // Logo
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 62),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Read',
                          style: AppStyles.readTextBold.copyWith(
                            fontSize: 64,
                          ),
                        ),
                        SizedBox(width: 5),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 125,
                              height: 40,
                              child: Text(
                                'Right',
                                style: AppStyles.rightText.copyWith(
                                  fontSize: 48,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 5),
                            Container(
                              width: 90,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.darkGray,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 50.0),
                  // Mascot illustration
                  Center(
                    child: SvgPicture.asset(
                      'assets/mascot/yeti_drink.svg',
                      width: 327,
                      height: 537,
                      semanticsLabel: 'Yeti drinking beverage',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
