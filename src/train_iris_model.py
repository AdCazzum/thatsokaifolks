#!/usr/bin/env python3
"""
Train a Random Forest classifier on the Iris dataset and save the model.
"""

import argparse
import pickle

import polars as pl
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split


def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(
        description="Train a Random Forest classifier on the Iris dataset"
    )
    parser.add_argument("input_file", help="Path to the input CSV file")
    parser.add_argument(
        "--output-dir",
        default="/tmp",
        help="Directory to save the model (default: /tmp)",
    )
    args = parser.parse_args()

    # Load the iris dataset
    print(f"Loading iris dataset from {args.input_file}...")
    try:
        df = pl.read_csv(args.input_file)
    except FileNotFoundError:
        print(f"Error: {args.input_file} not found.")
        return 1
    except Exception as e:
        print(f"Error loading dataset: {e}")
        return 1

    print(f"Dataset shape: {df.shape}")
    print(f"Columns: {df.columns}")

    # Prepare features and target
    # Assuming the last column is the target (species)
    feature_columns = df.columns[:-1]  # All columns except the last
    target_column = df.columns[-1]  # Last column

    X = df.select(feature_columns).to_numpy()
    y = df.select(target_column).to_numpy().ravel()

    print(f"Features shape: {X.shape}")
    print(f"Target classes: {pl.Series(y).unique()}")

    # Split the data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    print(f"Training set size: {len(X_train)}")
    print(f"Test set size: {len(X_test)}")

    # Train Random Forest classifier
    print("Training Random Forest classifier...")
    rf_classifier = RandomForestClassifier(
        n_estimators=100,
        random_state=42,
        max_depth=5,
        min_samples_split=2,
        min_samples_leaf=1,
    )

    rf_classifier.fit(X_train, y_train)

    # Evaluate the model
    y_pred = rf_classifier.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)

    print(f"Model accuracy: {accuracy:.4f}")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred))

    # Feature importance
    feature_names = list(feature_columns)
    feature_importance = pl.DataFrame(
        {"feature": feature_names, "importance": rf_classifier.feature_importances_}
    ).sort("importance", descending=True)

    print("\nFeature Importance:")
    print(feature_importance)

    # Save the model
    model_path = f"{args.output_dir}/iris_random_forest_model.pkl"
    print(f"\nSaving model to {model_path}...")

    try:
        with open(model_path, "wb") as f:
            pickle.dump(rf_classifier, f)
        print("Model saved successfully!")
    except Exception as e:
        print(f"Error saving model: {e}")
        return 1

    # Save feature names for future use
    feature_names_path = f"{args.output_dir}/iris_feature_names.pkl"
    with open(feature_names_path, "wb") as f:
        pickle.dump(feature_names, f)

    # Save model metadata
    metadata = {
        "model_type": "RandomForestClassifier",
        "accuracy": accuracy,
        "n_estimators": rf_classifier.n_estimators,
        "feature_names": feature_names,
        "target_classes": list(pl.Series(y).unique()),
        "training_samples": len(X_train),
        "test_samples": len(X_test),
    }

    metadata_path = f"{args.output_dir}/iris_model_metadata.pkl"
    with open(metadata_path, "wb") as f:
        pickle.dump(metadata, f)

    print(f"Feature names saved to {feature_names_path}")
    print(f"Model metadata saved to {metadata_path}")
    print("\nTraining completed successfully!")

    return 0


if __name__ == "__main__":
    exit(main())
