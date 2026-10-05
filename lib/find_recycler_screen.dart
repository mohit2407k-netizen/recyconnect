import 'package:flutter/material.dart';

class FindRecyclerScreen extends StatelessWidget {
  const FindRecyclerScreen({super.key});

  final List<Map<String, dynamic>> recyclers = const [
    {
      'name': 'Green Earth Recycling',
      'address': 'Jhansi, Uttar Pradesh',
      'distance': '2.5 km',
      'rating': 4.7,
      'verified': true,
    },
    {
      'name': 'Eco Recyclers',
      'address': 'Civil Lines, Jhansi',
      'distance': '4.1 km',
      'rating': 4.5,
      'verified': true,
    },
    {
      'name': 'CleanTech Recycling',
      'address': 'Sipri Bazar, Jhansi',
      'distance': '5.8 km',
      'rating': 4.3,
      'verified': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Recycler'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: recyclers.length,
        itemBuilder: (context, index) {
          final recycler = recyclers[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        child: Icon(
                          Icons.recycling,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              recycler['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              recycler['address'],
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (recycler['verified'])
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(recycler['distance']),

                      const SizedBox(width: 20),

                      const Icon(
                        Icons.star,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recycler['rating'].toString(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Step 6: Recycler Details
                      },
                      child: const Text('View Recycler'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}