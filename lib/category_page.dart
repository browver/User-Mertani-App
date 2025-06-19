import 'package:flutter/material.dart';
import 'package:flutter_application_2/category_model.dart';
import 'package:flutter_application_2/firebase_services.dart';
import 'package:flutter_application_2/product_by_category.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final FirestoreServices firestore = FirestoreServices();

  final TextEditingController _nameController = TextEditingController();
  IconData selectedIcon = Icons.category;
  bool deleteProducts = false;

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add Category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Category Name'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<IconData>(
                    value: selectedIcon,
                    items: [
                      Icons.category,
                      Icons.memory,
                      Icons.sensors,
                      Icons.sensor_window,
                      Icons.bolt,
                    ].map((icon) {
                      return DropdownMenuItem(
                        value: icon,
                        child: Row(
                          children: [
                            Icon(icon),
                            const SizedBox(width: 10),
                            Text(icon.codePoint.toString()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedIcon = value!;
                      });
                    },
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    firestore.addCategory(_nameController.text, selectedIcon.codePoint);
                    Navigator.pop(context);
                    _nameController.clear();
                  },
                  child: const Text('Add'),
              )
            ],
            );
          },
       );
     },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<CategoryModel>>(
        stream: firestore.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text(
                  'Error loading categories:\n${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final categories = snapshot.data!;
          if (categories.isEmpty) return const Text("No categories found");

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
            // Hapus Kategori
              return ListTile(
                leading: Icon(category.icon),
                title: Text(category.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        bool localDeleteProducts = deleteProducts;

                        final confirm = await showDialog(
                          context: context, 
                          builder:(context) {
                            return StatefulBuilder(
                              builder: (contenxt, setStateDialog) {
                                return AlertDialog(
                                title: const Text('Hapus Kategori'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Yakin ingin menghapus kategori "${category.name}" ?'),
                                    const SizedBox(height: 10),
                                    CheckboxListTile(
                                      value: localDeleteProducts, 
                                      onChanged: (value) {
                                        setStateDialog(() {
                                          localDeleteProducts = value!;
                                        });
                                      },
                                      title: const Text('Hapus semua produk dalam kategori ini'),
                                      controlAffinity: ListTileControlAffinity.leading,
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context,false), 
                                    child: const Text('Batal')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true), 
                                    child: const Text('Hapus')),
                                  ],
                                );
                              },
                            );
                        },
                      );

                          if (confirm == true) {
                            if (localDeleteProducts) {
                              await firestore.deleteCategoryWithProducts(category.name);
                            } else {
                              await firestore.deleteCategory(category.name);
                            }
                          }
                      },
                    ),
                    const Icon(Icons.arrow_forward_ios, size:  16),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => ProductByCategoryPage(categoryName: category.name)));
                },
              );
            },
          );
        },
      ),
    );
  }
}