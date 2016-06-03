This gem overrides Ruby's special `method_missing` method that is called whenever you call a method that doesn't exist.
Instead of throwing an exception, this gem will Google for StackOverflow code snippets with your method name, inject
them into your code, run them until one doesn't _also_ throw an exception, and then return to your original calling function
with the successful snippet's result.
